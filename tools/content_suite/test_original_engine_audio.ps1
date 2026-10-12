[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $GameRoot,

    [string] $GodotConsole = "",

    [ValidateRange(8000, 192000)]
    [int] $ProbeSampleRate = 22050,

    [ValidateRange(100, 10000)]
    [int] $ProbeFrequency = 880,

    [ValidateRange(1, 10)]
    [int] $MeasurementSeconds = 5,

    [ValidateRange(1, 100)]
    [int] $SampleIntervalMilliseconds = 10,

    [ValidateRange(0.0001, 1.0)]
    [double] $MinimumPeak = 0.005,

    [ValidateRange(100, 5000)]
    [int] $MinimumActiveMilliseconds = 700,

    [ValidateRange(100, 5000)]
    [int] $MaximumActiveMilliseconds = 1600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SmokePrefix = "kakyu-original-engine-smoke-"
$AudioEntry = "KSE0031.WAV"
$ProbeSeconds = 1
$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$MeterSource = Join-Path $PSScriptRoot "windows_audio_session_meter.cs"
$PrepareScript = "res://tools/content_suite/cli/prepare_arc_smoke_copy.gd"


function Resolve-Executable {
    param(
        [string] $Requested,
        [string] $DefaultName
    )

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


function Write-ProbeWave {
    param(
        [string] $Path,
        [int] $SampleRate,
        [int] $Frequency,
        [int] $Seconds
    )

    $sampleCount = $SampleRate * $Seconds
    $dataSize = $sampleCount * 2
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $ascii = [Text.Encoding]::ASCII
        $writer.Write($ascii.GetBytes("RIFF"))
        $writer.Write([uint32](36 + $dataSize))
        $writer.Write($ascii.GetBytes("WAVE"))
        $writer.Write($ascii.GetBytes("fmt "))
        $writer.Write([uint32]16)
        $writer.Write([uint16]1)
        $writer.Write([uint16]1)
        $writer.Write([uint32]$SampleRate)
        $writer.Write([uint32]($SampleRate * 2))
        $writer.Write([uint16]2)
        $writer.Write([uint16]16)
        $writer.Write($ascii.GetBytes("data"))
        $writer.Write([uint32]$dataSize)
        for ($index = 0; $index -lt $sampleCount; $index++) {
            $phase = 2.0 * [Math]::PI * $Frequency * $index / $SampleRate
            $sample = [int16][Math]::Round([Math]::Sin($phase) * 6553.0)
            $writer.Write($sample)
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}


function Set-IsolatedAudioFlags {
    param([string] $Path)

    $encoding = [Text.Encoding]::GetEncoding(932)
    $text = [IO.File]::ReadAllText($Path, $encoding)
    $settings = @{
        "IsMusic" = 0
        "IsVoice" = 0
        "IsEffect" = 1
    }
    foreach ($name in $settings.Keys) {
        $pattern = "(?m)^$name[ \t]*=[ \t]*\d+[ \t]*\r?$"
        $replacement = "$name=$($settings[$name])"
        if (-not [regex]::IsMatch($text, $pattern)) {
            throw "Required audio setting is missing from isolated AI5WIN.INI: $name"
        }
        $text = [regex]::Replace($text, $pattern, $replacement)
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
    if ($null -eq $parent -or
        -not [string]::Equals(
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
    param(
        [string[]] $HashedPaths,
        [IO.FileInfo[]] $Archives
    )

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
    return [pscustomobject]@{
        Hashes = $hashes
        ArchiveMetadata = $archiveMetadata
    }
}


function Assert-SourceUnchanged {
    param([object] $Snapshot)

    foreach ($path in $Snapshot.Hashes.Keys) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Source file disappeared during smoke test: $path"
        }
        $currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
        if ($currentHash -ne $Snapshot.Hashes[$path]) {
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


if ($MaximumActiveMilliseconds -lt $MinimumActiveMilliseconds) {
    throw "MaximumActiveMilliseconds must be greater than or equal to MinimumActiveMilliseconds."
}
if ($ProbeFrequency * 2 -ge $ProbeSampleRate) {
    throw "ProbeFrequency must be below half of ProbeSampleRate."
}
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container) -or
    -not (Test-Path -LiteralPath (Join-Path $ProjectRoot "project.godot") -PathType Leaf)) {
    throw "The smoke-test script is not inside a Godot project: $ProjectRoot"
}
if (-not (Test-Path -LiteralPath $MeterSource -PathType Leaf)) {
    throw "Core Audio meter source is missing: $MeterSource"
}

$resolvedGameRoot = [IO.Path]::GetFullPath($GameRoot).TrimEnd("\")
$sourceElfImage = Join-Path $resolvedGameRoot "ELFIMAGE"
$sourceEngine = Join-Path $resolvedGameRoot "AI5WIN.original.exe"
$sourceIni = Join-Path $sourceElfImage "AI5WIN.INI"
$sourceSeArchive = Join-Path $sourceElfImage "se.arc"
foreach ($requiredPath in @($sourceEngine, $sourceIni, $sourceSeArchive)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required original-engine file is missing: $requiredPath"
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
$hashedSourcePaths.Add($sourceSeArchive)
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
$temporaryDrive = [IO.DriveInfo]::new(
    [IO.Path]::GetPathRoot([IO.Path]::GetTempPath())
)
if ($temporaryDrive.AvailableFreeSpace -lt $requiredTemporaryBytes) {
    throw (
        "Insufficient temporary-drive space for isolated original-engine test: " +
        "$($temporaryDrive.AvailableFreeSpace) < $requiredTemporaryBytes bytes"
    )
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
        if (-not $archive.Name.Equals("se.arc", [StringComparison]::OrdinalIgnoreCase)) {
            Copy-Item -LiteralPath $archive.FullName -Destination $smokeElfImage
        }
    }
    foreach ($saveFile in $sourceSaveFiles) {
        Copy-Item -LiteralPath $saveFile.FullName -Destination $smokeSave
    }

    $isolatedIni = Join-Path $smokeElfImage "AI5WIN.INI"
    Set-IsolatedAudioFlags -Path $isolatedIni
    $probePath = Join-Path $smokeRoot "probe.wav"
    Write-ProbeWave `
        -Path $probePath `
        -SampleRate $ProbeSampleRate `
        -Frequency $ProbeFrequency `
        -Seconds $ProbeSeconds

    $smokeSeArchive = Join-Path $smokeElfImage "se.arc"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $prepareOutput = @(
            & $godotPath `
                --headless `
                --path $ProjectRoot `
                --script $PrepareScript `
                -- `
                $sourceSeArchive `
                $AudioEntry `
                $smokeSeArchive `
                $probePath 2>&1
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
        throw "Content Core ARC preparation failed with exit code $prepareExitCode."
    }
    $prepareText = $prepareOutput -join "`n"
    $prepareMatch = [regex]::Match(
        $prepareText,
        "SMOKE_PREPARE_PASS entry=KSE0031\.WAV .* output_sha256=([0-9a-f]{64})",
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $prepareMatch.Success) {
        throw "Content Core ARC preparation did not report a verified KSE0031.WAV output."
    }
    $outputArchiveHash = $prepareMatch.Groups[1].Value.ToLowerInvariant()

    Add-Type -Path $MeterSource
    $outer = Start-Process `
        -FilePath (Join-Path $smokeRoot "AI5WIN.exe") `
        -WorkingDirectory $smokeRoot `
        -PassThru

    $childDeadline = [DateTime]::UtcNow.AddSeconds(15)
    $gameProcess = $null
    while ([DateTime]::UtcNow -lt $childDeadline) {
        foreach ($candidate in @(Get-SmokeProcesses -Root $smokeRoot)) {
            if ($candidate.ProcessName -eq "AI5WIN.log") {
                $gameProcess = $candidate
                break
            }
        }
        if ($null -ne $gameProcess) {
            break
        }
        Start-Sleep -Milliseconds 10
    }
    if ($null -eq $gameProcess) {
        throw "The original-engine child process did not start within 15 seconds."
    }

    $measurement = [Diagnostics.Stopwatch]::StartNew()
    $sessionFirstMilliseconds = -1
    $firstActiveMilliseconds = -1
    $lastActiveMilliseconds = -1
    $maximumPeak = -1.0
    $activeSamples = 0
    $totalSamples = 0
    while ($measurement.ElapsedMilliseconds -lt $MeasurementSeconds * 1000) {
        $peak = [Kakyu.ContentTools.WindowsAudioSessionMeter]::ReadPeak(
            [uint32]$gameProcess.Id
        )
        $elapsed = $measurement.ElapsedMilliseconds
        $totalSamples++
        if ($peak -ge 0.0 -and $sessionFirstMilliseconds -lt 0) {
            $sessionFirstMilliseconds = $elapsed
        }
        if ($peak -gt $maximumPeak) {
            $maximumPeak = $peak
        }
        if ($peak -gt $MinimumPeak) {
            $activeSamples++
            if ($firstActiveMilliseconds -lt 0) {
                $firstActiveMilliseconds = $elapsed
            }
            $lastActiveMilliseconds = $elapsed
        }
        Start-Sleep -Milliseconds $SampleIntervalMilliseconds
    }

    try {
        $gameProcess.Refresh()
    }
    catch {
        throw "The original-engine child process exited during measurement."
    }
    if ($gameProcess.HasExited) {
        throw "The original-engine child process exited during measurement."
    }
    if (-not $gameProcess.Responding) {
        throw "The original-engine child process stopped responding."
    }
    if ([string]::IsNullOrWhiteSpace($gameProcess.MainWindowTitle)) {
        throw "The original-engine child process did not create a titled game window."
    }
    if ($sessionFirstMilliseconds -lt 0) {
        throw "No Core Audio session appeared for the original-engine child process."
    }
    if ($firstActiveMilliseconds -lt 0) {
        throw "No effect-only audio peak exceeded $MinimumPeak."
    }
    $activeSpanMilliseconds = $lastActiveMilliseconds - $firstActiveMilliseconds
    if ($activeSpanMilliseconds -lt $MinimumActiveMilliseconds -or
        $activeSpanMilliseconds -gt $MaximumActiveMilliseconds) {
        throw (
            "Effect-only active span was outside the expected probe window: " +
            "$activeSpanMilliseconds ms"
        )
    }

    $result = [pscustomobject]@{
        Status = "PASS"
        Entry = $AudioEntry
        ProbeSeconds = $ProbeSeconds
        ProbeSampleRate = $ProbeSampleRate
        ProbeFrequency = $ProbeFrequency
        OutputArchiveSha256 = $outputArchiveHash
        ChildProcessId = $gameProcess.Id
        WindowTitle = $gameProcess.MainWindowTitle
        SessionFirstMilliseconds = $sessionFirstMilliseconds
        FirstActiveMilliseconds = $firstActiveMilliseconds
        LastActiveMilliseconds = $lastActiveMilliseconds
        ActiveSpanMilliseconds = $activeSpanMilliseconds
        MaximumPeak = $maximumPeak
        ActiveSamples = $activeSamples
        TotalSamples = $totalSamples
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
    "ORIGINAL_ENGINE_AUDIO_SMOKE_PASS entry={0} active_ms={1} max_peak={2:F8} " +
    "archive_sha256={3}"
) -f @(
        $result.Entry,
        $result.ActiveSpanMilliseconds,
        $result.MaximumPeak,
        $result.OutputArchiveSha256
)
Write-Output $summary
