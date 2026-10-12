[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $GameRoot,

    [string] $GodotConsole = "",

    [string] $EvidencePath = "",

    [ValidateRange(5, 60)]
    [int] $MarkerTimeoutSeconds = 20,

    [ValidateRange(50, 1000)]
    [int] $CaptureIntervalMilliseconds = 150
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SmokePrefix = "kakyu-original-engine-image-smoke-"
$EntryPrefix = "LOGOBKC"
$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$PrepareScript = "res://tools/content_suite/cli/prepare_image_smoke_copy.gd"


function Resolve-Executable {
    param([string] $Requested, [string] $DefaultName)

    $candidate = $Requested
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = $DefaultName
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Executable was not found: $candidate"
    }
    return $command.Source
}


function Set-IsolatedAudioFlags {
    param([string] $Path)

    $encoding = [Text.Encoding]::GetEncoding(932)
    $text = [IO.File]::ReadAllText($Path, $encoding)
    foreach ($name in @("IsMusic", "IsVoice", "IsEffect")) {
        $pattern = "(?m)^$name[ \t]*=[ \t]*\d+[ \t]*\r?$"
        if (-not [regex]::IsMatch($text, $pattern)) {
            throw "Required audio setting is missing from isolated AI5WIN.INI: $name"
        }
        $text = [regex]::Replace($text, $pattern, "$name=0")
    }
    [IO.File]::WriteAllText($Path, $text, $encoding)
}


function Get-SmokeProcesses {
    param([string] $Root)

    $processes = New-Object System.Collections.Generic.List[object]
    foreach ($process in Get-Process -ErrorAction SilentlyContinue) {
        try {
            $path = $process.Path
            if ($path -and $path.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
                $processes.Add($process)
            }
        }
        catch {
            continue
        }
    }
    return $processes.ToArray()
}


function Stop-SmokeProcesses {
    param([string] $Root)

    $processes = @(Get-SmokeProcesses -Root $Root)
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    foreach ($process in $processes) {
        Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
}


function Remove-SmokeDirectory {
    param([string] $Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        return
    }
    $resolved = [IO.Path]::GetFullPath($Root).TrimEnd("\")
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd("\")
    $parent = [IO.Directory]::GetParent($resolved)
    if ($null -eq $parent -or -not [string]::Equals(
        $parent.FullName.TrimEnd("\"),
        $tempRoot,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to remove a directory outside the system temporary root: $resolved"
    }
    if (-not [IO.Path]::GetFileName($resolved).StartsWith(
        $SmokePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to remove a directory without the smoke-test prefix: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    if (Test-Path -LiteralPath $resolved) {
        throw "Smoke-test cleanup failed: $resolved"
    }
}


function New-SourceSnapshot {
    param([string[]] $HashedPaths, [IO.FileInfo[]] $Archives)

    $hashes = @{}
    foreach ($path in $HashedPaths) {
        $hashes[$path] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    }
    $archiveMetadata = @{}
    foreach ($archive in $Archives) {
        $archiveMetadata[$archive.FullName] = [pscustomobject]@{
            Length = $archive.Length
            LastWriteTimeUtcTicks = $archive.LastWriteTimeUtc.Ticks
        }
    }
    return [pscustomobject]@{ Hashes = $hashes; ArchiveMetadata = $archiveMetadata }
}


function Assert-SourceUnchanged {
    param([object] $Snapshot)

    foreach ($path in $Snapshot.Hashes.Keys) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Source file disappeared during smoke test: $path"
        }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -ne $Snapshot.Hashes[$path]) {
            throw "Source file hash changed during smoke test: $path"
        }
    }
    foreach ($path in $Snapshot.ArchiveMetadata.Keys) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Source archive disappeared during smoke test: $path"
        }
        $archive = Get-Item -LiteralPath $path
        $expected = $Snapshot.ArchiveMetadata[$path]
        if ($archive.Length -ne $expected.Length -or
            $archive.LastWriteTimeUtc.Ticks -ne $expected.LastWriteTimeUtcTicks) {
            throw "Source archive metadata changed during smoke test: $path"
        }
    }
}


function Find-SmokeGameProcess {
    param([string] $Root)

    foreach ($process in @(Get-SmokeProcesses -Root $Root)) {
        try {
            $process.Refresh()
            if (-not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
                return $process
            }
        }
        catch {
            continue
        }
    }
    return $null
}


Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class KakyuImageSmokeWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);
}
"@


function Capture-ClientBitmap {
    param([IntPtr] $WindowHandle)

    $rect = New-Object KakyuImageSmokeWindow+RECT
    $point = New-Object KakyuImageSmokeWindow+POINT
    if (-not [KakyuImageSmokeWindow]::GetClientRect($WindowHandle, [ref]$rect) -or
        -not [KakyuImageSmokeWindow]::ClientToScreen($WindowHandle, [ref]$point)) {
        throw "Could not resolve the original-engine client rectangle."
    }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -lt 320 -or $height -lt 200) {
        throw "Original-engine client rectangle is unexpectedly small: ${width}x${height}"
    }
    $bitmap = New-Object Drawing.Bitmap($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($point.X, $point.Y, 0, 0, $bitmap.Size)
    }
    finally {
        $graphics.Dispose()
    }
    return $bitmap
}


function Measure-SmokeMarker {
    param([Drawing.Bitmap] $Bitmap)

    $magenta = 0
    $green = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y += 2) {
        for ($x = 0; $x -lt $Bitmap.Width; $x += 2) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.R -ge 235 -and $pixel.G -le 25 -and $pixel.B -ge 235) {
                $magenta++
            }
            if ($pixel.R -le 25 -and $pixel.G -ge 235 -and $pixel.B -le 25) {
                $green++
            }
        }
    }
    return [pscustomobject]@{
        Seen = ($magenta -ge 300 -and $green -ge 100)
        MagentaSamples = $magenta
        GreenSamples = $green
    }
}


if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container) -or
    -not (Test-Path -LiteralPath (Join-Path $ProjectRoot "project.godot") -PathType Leaf)) {
    throw "The smoke-test script is not inside a Godot project: $ProjectRoot"
}

$resolvedGameRoot = [IO.Path]::GetFullPath($GameRoot).TrimEnd("\")
$sourceElfImage = Join-Path $resolvedGameRoot "ELFIMAGE"
$sourceEngine = Join-Path $resolvedGameRoot "AI5WIN.original.exe"
$sourceIni = Join-Path $sourceElfImage "AI5WIN.INI"
$sourceMmoArchive = Join-Path $sourceElfImage "mmo.arc"
foreach ($requiredPath in @($sourceEngine, $sourceIni, $sourceMmoArchive)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required original-engine file is missing: $requiredPath"
    }
}

$resolvedEvidencePath = ""
if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
    $resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
    if (Test-Path -LiteralPath $resolvedEvidencePath) {
        throw "Evidence output already exists: $resolvedEvidencePath"
    }
    if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($resolvedEvidencePath)) -PathType Container)) {
        throw "Evidence output parent does not exist: $resolvedEvidencePath"
    }
}

$sourceArchives = @(Get-ChildItem -LiteralPath $sourceElfImage -Filter "*.arc" -File)
if ($sourceArchives.Count -eq 0) {
    throw "No ARC files were found under: $sourceElfImage"
}
$sourceSave = Join-Path $sourceElfImage "save"
$sourceSaveFiles = @()
if (Test-Path -LiteralPath $sourceSave -PathType Container) {
    $sourceSaveFiles = @(
        Get-ChildItem -LiteralPath $sourceSave -File |
            Where-Object { $_.Name -match "^FLAG\d\d$" -or $_.Name -eq "MesSkip.dat" }
    )
}

$hashedSourcePaths = New-Object System.Collections.Generic.List[string]
$hashedSourcePaths.Add($sourceEngine)
$hashedSourcePaths.Add($sourceIni)
$hashedSourcePaths.Add($sourceMmoArchive)
foreach ($saveFile in $sourceSaveFiles) {
    $hashedSourcePaths.Add($saveFile.FullName)
}
$sourceSnapshot = New-SourceSnapshot `
    -HashedPaths $hashedSourcePaths.ToArray() `
    -Archives $sourceArchives

$requiredTemporaryBytes = 64MB + (Get-Item -LiteralPath $sourceEngine).Length
foreach ($archive in $sourceArchives) {
    $requiredTemporaryBytes += $archive.Length
}
foreach ($saveFile in $sourceSaveFiles) {
    $requiredTemporaryBytes += $saveFile.Length
}
$temporaryDrive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot([IO.Path]::GetTempPath()))
if ($temporaryDrive.AvailableFreeSpace -lt $requiredTemporaryBytes) {
    throw "Insufficient temporary-drive space for isolated original-engine image test."
}

$godotPath = Resolve-Executable `
    -Requested $GodotConsole `
    -DefaultName "Godot_v4.7-stable_win64_console.exe"
$smokeRoot = Join-Path `
    ([IO.Path]::GetTempPath()) `
    ($SmokePrefix + [guid]::NewGuid().ToString("N"))
$result = $null
$primaryError = $null

try {
    $smokeElfImage = Join-Path $smokeRoot "ELFIMAGE"
    $smokeSave = Join-Path $smokeElfImage "save"
    New-Item -ItemType Directory -Path $smokeSave -Force | Out-Null

    Copy-Item -LiteralPath $sourceEngine -Destination (Join-Path $smokeRoot "AI5WIN.exe")
    foreach ($optionalName in @("ddraw.dll", "DDrawCompat.ini", "DDrawCompat-AI5WIN.ini")) {
        $optionalSource = Join-Path $resolvedGameRoot $optionalName
        if (Test-Path -LiteralPath $optionalSource -PathType Leaf) {
            Copy-Item -LiteralPath $optionalSource -Destination $smokeRoot
        }
    }
    Copy-Item -LiteralPath $sourceIni -Destination (Join-Path $smokeElfImage "AI5WIN.INI")
    foreach ($archive in $sourceArchives) {
        if (-not $archive.Name.Equals("mmo.arc", [StringComparison]::OrdinalIgnoreCase)) {
            Copy-Item -LiteralPath $archive.FullName -Destination $smokeElfImage
        }
    }
    foreach ($saveFile in $sourceSaveFiles) {
        Copy-Item -LiteralPath $saveFile.FullName -Destination $smokeSave
    }
    Set-IsolatedAudioFlags -Path (Join-Path $smokeElfImage "AI5WIN.INI")

    $smokeMmoArchive = Join-Path $smokeElfImage "mmo.arc"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $prepareOutput = @(
            & $godotPath `
                --headless `
                --path $ProjectRoot `
                --script $PrepareScript `
                -- `
                $sourceMmoArchive `
                $EntryPrefix `
                $smokeMmoArchive 2>&1
        )
        $prepareExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    foreach ($line in $prepareOutput) {
        Write-Verbose $line
    }
    if ($prepareExitCode -ne 0) {
        throw "Content Core image ARC preparation failed with exit code $prepareExitCode."
    }
    $preparePattern = "IMAGE_SMOKE_PREPARE_PASS prefix={0} entries=(\d+) .* output_sha256=([0-9a-f]{{64}})" -f [regex]::Escape($EntryPrefix)
    $prepareMatch = [regex]::Match(
        ($prepareOutput -join "`n"),
        $preparePattern,
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $prepareMatch.Success) {
        throw "Content Core image ARC preparation did not report a verified $EntryPrefix output."
    }
    $replacementCount = [int]$prepareMatch.Groups[1].Value
    $outputArchiveHash = $prepareMatch.Groups[2].Value.ToLowerInvariant()

    $outer = Start-Process `
        -FilePath (Join-Path $smokeRoot "AI5WIN.exe") `
        -WorkingDirectory $smokeRoot `
        -PassThru

    $windowDeadline = [DateTime]::UtcNow.AddSeconds(15)
    $gameProcess = $null
    while ([DateTime]::UtcNow -lt $windowDeadline) {
        $gameProcess = Find-SmokeGameProcess -Root $smokeRoot
        if ($null -ne $gameProcess) {
            break
        }
        Start-Sleep -Milliseconds 50
    }
    if ($null -eq $gameProcess) {
        throw "The isolated original engine did not create a game window within 15 seconds."
    }

    $markerDeadline = [DateTime]::UtcNow.AddSeconds($MarkerTimeoutSeconds)
    $marker = $null
    $captures = 0
    $lastBitmap = $null
    while ([DateTime]::UtcNow -lt $markerDeadline) {
        try {
            $gameProcess.Refresh()
            if ($gameProcess.HasExited) {
                throw "The isolated original engine exited before marker detection."
            }
            if (-not $gameProcess.Responding) {
                throw "The isolated original engine stopped responding."
            }
            if ($null -ne $lastBitmap) {
                $lastBitmap.Dispose()
            }
            $lastBitmap = Capture-ClientBitmap -WindowHandle $gameProcess.MainWindowHandle
            $captures++
            $marker = Measure-SmokeMarker -Bitmap $lastBitmap
            if ($marker.Seen) {
                break
            }
        }
        catch {
            if ($_.Exception.Message -match "exited|responding") {
                throw
            }
        }
        Start-Sleep -Milliseconds $CaptureIntervalMilliseconds
    }
    if ($null -eq $marker -or -not $marker.Seen) {
        if ($null -ne $lastBitmap -and -not [string]::IsNullOrWhiteSpace($resolvedEvidencePath)) {
            $lastBitmap.Save($resolvedEvidencePath, [Drawing.Imaging.ImageFormat]::Png)
        }
        throw "The $EntryPrefix magenta/green marker was not detected within $MarkerTimeoutSeconds seconds."
    }
    if (-not [string]::IsNullOrWhiteSpace($resolvedEvidencePath)) {
        $lastBitmap.Save($resolvedEvidencePath, [Drawing.Imaging.ImageFormat]::Png)
    }
    $clientWidth = $lastBitmap.Width
    $clientHeight = $lastBitmap.Height
    $lastBitmap.Dispose()
    $lastBitmap = $null

    $result = [pscustomobject]@{
        Status = "PASS"
        EntryPrefix = $EntryPrefix
        ReplacementCount = $replacementCount
        OutputArchiveSha256 = $outputArchiveHash
        ChildProcessId = $gameProcess.Id
        WindowTitle = $gameProcess.MainWindowTitle
        ClientWidth = $clientWidth
        ClientHeight = $clientHeight
        Captures = $captures
        MagentaSamples = $marker.MagentaSamples
        GreenSamples = $marker.GreenSamples
        EvidencePath = $resolvedEvidencePath
        SourceUnchanged = $true
        TemporaryDataRemoved = $true
    }
}
catch {
    $primaryError = $_
}
finally {
    try {
        Stop-SmokeProcesses -Root $smokeRoot
        Assert-SourceUnchanged -Snapshot $sourceSnapshot
        Remove-SmokeDirectory -Root $smokeRoot
    }
    catch {
        if ($null -eq $primaryError) {
            $primaryError = $_
        }
        else {
            Write-Warning "Additional cleanup or source-integrity failure: $_"
        }
    }
}

if ($null -ne $primaryError) {
    throw $primaryError
}

$result
$summary = (
    "ORIGINAL_ENGINE_IMAGE_SMOKE_PASS prefix={0} entries={1} client={2}x{3} " +
    "magenta={4} green={5} archive_sha256={6}"
) -f @(
    $result.EntryPrefix,
    $result.ReplacementCount,
    $result.ClientWidth,
    $result.ClientHeight,
    $result.MagentaSamples,
    $result.GreenSamples,
    $result.OutputArchiveSha256
)
Write-Output $summary
