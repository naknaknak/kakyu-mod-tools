[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $GameRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputRoot,

    [string] $GodotConsole = "",

    [switch] $PlanOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Schema = "kakyu_original_engine_verification_batch/v1"
$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$ExpectedHashes = @{
    "AI5WIN.original.exe" = "3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5"
    "mes.arc" = "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
    "data.arc" = "b069c4dbb67d67eaf9252babc02f100fbc16c0740a189b007ff31535305727e4"
    "voice.arc" = "12278db46895d35ddc73a489dd82857be560406ba83c5a7fdfac3ba415545322"
}


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


function Test-IsBelow {
    param([string] $Candidate, [string] $Parent)

    $candidatePath = [IO.Path]::GetFullPath($Candidate).TrimEnd("\")
    $parentPath = [IO.Path]::GetFullPath($Parent).TrimEnd("\")
    return $candidatePath.StartsWith(
        $parentPath + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
}


function Get-SourceSnapshot {
    param([hashtable] $Paths)

    $snapshot = @{}
    foreach ($name in $Paths.Keys) {
        $item = Get-Item -LiteralPath $Paths[$name]
        $snapshot[$name] = [pscustomobject]@{
            Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToLowerInvariant()
            Length = $item.Length
            LastWriteTimeUtcTicks = $item.LastWriteTimeUtc.Ticks
        }
    }
    return $snapshot
}


function Assert-SourceUnchanged {
    param([hashtable] $Paths, [hashtable] $Snapshot)

    foreach ($name in $Paths.Keys) {
        if (-not (Test-Path -LiteralPath $Paths[$name] -PathType Leaf)) {
            throw "Source file disappeared during preparation: $name"
        }
        $item = Get-Item -LiteralPath $Paths[$name]
        $expected = $Snapshot[$name]
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToLowerInvariant()
        if ($hash -ne $expected.Hash -or
            $item.Length -ne $expected.Length -or
            $item.LastWriteTimeUtc.Ticks -ne $expected.LastWriteTimeUtcTicks) {
            throw "Source file changed during preparation: $name"
        }
    }
}


function Invoke-GodotPreparer {
    param(
        [string] $GodotPath,
        [string] $Script,
        [string[]] $Arguments,
        [string] $PassToken
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = @(
            & $GodotPath `
                --headless `
                --path $ProjectRoot `
                --script $Script `
                -- `
                @Arguments 2>&1
        )
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    foreach ($line in $output) {
        Write-Verbose $line
    }
    if ($exitCode -ne 0) {
        throw "$Script failed with exit code $exitCode."
    }
    if (-not (($output -join "`n").Contains($PassToken))) {
        throw "$Script did not report $PassToken."
    }
}


function Remove-StagingRoot {
    param([string] $Path, [string] $ExpectedParent, [string] $ExpectedPrefix)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $resolved = [IO.Path]::GetFullPath($Path).TrimEnd("\")
    $parent = [IO.Directory]::GetParent($resolved)
    if ($null -eq $parent -or
        -not [string]::Equals(
            $parent.FullName.TrimEnd("\"),
            [IO.Path]::GetFullPath($ExpectedParent).TrimEnd("\"),
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not [IO.Path]::GetFileName($resolved).StartsWith(
            $ExpectedPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Refusing to remove an unexpected staging directory: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}


if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "project.godot") -PathType Leaf)) {
    throw "The batch preparer is not inside a Godot project: $ProjectRoot"
}
$resolvedGameRoot = [IO.Path]::GetFullPath($GameRoot).TrimEnd("\")
$sourceElfImage = Join-Path $resolvedGameRoot "ELFIMAGE"
$sourcePaths = @{
    "AI5WIN.original.exe" = Join-Path $resolvedGameRoot "AI5WIN.original.exe"
    "mes.arc" = Join-Path $sourceElfImage "mes.arc"
    "data.arc" = Join-Path $sourceElfImage "data.arc"
    "voice.arc" = Join-Path $sourceElfImage "voice.arc"
}
foreach ($name in $sourcePaths.Keys) {
    if (-not (Test-Path -LiteralPath $sourcePaths[$name] -PathType Leaf)) {
        throw "Required source file is missing: $name"
    }
}

$resolvedOutputRoot = [IO.Path]::GetFullPath($OutputRoot).TrimEnd("\")
if (Test-Path -LiteralPath $resolvedOutputRoot) {
    throw "Verification batch output already exists: $resolvedOutputRoot"
}
if ((Test-IsBelow -Candidate $resolvedOutputRoot -Parent $resolvedGameRoot) -or
    [string]::Equals(
        $resolvedOutputRoot,
        $resolvedGameRoot,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Verification output must be outside the source game installation."
}
$outputParent = [IO.Path]::GetDirectoryName($resolvedOutputRoot)
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
    throw "Verification output parent does not exist: $outputParent"
}

$sourceSnapshot = Get-SourceSnapshot -Paths $sourcePaths
foreach ($name in $ExpectedHashes.Keys) {
    if ($sourceSnapshot[$name].Hash -ne $ExpectedHashes[$name]) {
        throw (
            "Source identity mismatch for {0}: expected {1}, got {2}" -f
            $name, $ExpectedHashes[$name], $sourceSnapshot[$name].Hash
        )
    }
}

$requiredBytes = 64MB
foreach ($archiveName in @("mes.arc", "data.arc", "voice.arc")) {
    $requiredBytes += $sourceSnapshot[$archiveName].Length
}
$outputDrive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($resolvedOutputRoot))
if (-not $PlanOnly -and $outputDrive.AvailableFreeSpace -lt $requiredBytes) {
    throw (
        "Insufficient output-drive space for candidates: {0} < {1} bytes" -f
        $outputDrive.AvailableFreeSpace, $requiredBytes
    )
}

if ($PlanOnly) {
    Assert-SourceUnchanged -Paths $sourcePaths -Snapshot $sourceSnapshot
    Write-Output ((
        "ORIGINAL_ENGINE_BATCH_PREFLIGHT_PASS schema={0} candidates=mes,data,voice " +
        "required_bytes={1} launches_original_engine=false"
    ) -f $Schema, $requiredBytes)
    exit 0
}

$godotPath = Resolve-Executable `
    -Requested $GodotConsole `
    -DefaultName "Godot_v4.7-stable_win64_console.exe"
$outputLeaf = [IO.Path]::GetFileName($resolvedOutputRoot)
$stagingPrefix = $outputLeaf + ".staging-"
$stagingRoot = Join-Path $outputParent ($stagingPrefix + [guid]::NewGuid().ToString("N"))
$primaryError = $null

try {
    $candidateRoot = Join-Path $stagingRoot "candidates"
    New-Item -ItemType Directory -Path $candidateRoot | Out-Null
    $mesCandidate = Join-Path $candidateRoot "mes.arc"
    $dataCandidate = Join-Path $candidateRoot "data.arc"
    $voiceCandidate = Join-Path $candidateRoot "voice.arc"

    Invoke-GodotPreparer `
        -GodotPath $godotPath `
        -Script "res://tools/content_suite/cli/prepare_mes_smoke_copy.gd" `
        -Arguments @($sourcePaths["mes.arc"], "EVENTD03.MES", "0x29F", $mesCandidate) `
        -PassToken "MES_SMOKE_PREPARE_PASS"
    Invoke-GodotPreparer `
        -GodotPath $godotPath `
        -Script "res://tools/content_suite/cli/prepare_dat_pal_smoke_copy.gd" `
        -Arguments @($sourcePaths["data.arc"], "MACHIN_3", $dataCandidate) `
        -PassToken "DAT_PAL_SMOKE_PREPARE_PASS"
    Invoke-GodotPreparer `
        -GodotPath $godotPath `
        -Script "res://tools/content_suite/cli/prepare_audio_swap_smoke_copy.gd" `
        -Arguments @($sourcePaths["voice.arc"], "D0977.OGG", "D1033.OGG", $voiceCandidate) `
        -PassToken "AUDIO_SWAP_PREPARE_PASS"

    Assert-SourceUnchanged -Paths $sourcePaths -Snapshot $sourceSnapshot
    $candidates = @(
        [ordered]@{
            kind = "mes_equal_length_cp932"
            path = "candidates/mes.arc"
            source_sha256 = $sourceSnapshot["mes.arc"].Hash
            candidate_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $mesCandidate).Hash.ToLowerInvariant()
            bytes = (Get-Item -LiteralPath $mesCandidate).Length
            target_entries = @("EVENTD03.MES")
            coordinate = "0x029F"
            expected_observation = "31 repeated CP932 marker characters at the selected EVENTD03 line"
            compatibility = "original_engine_unverified"
        },
        [ordered]@{
            kind = "dat_pal_marker"
            path = "candidates/data.arc"
            source_sha256 = $sourceSnapshot["data.arc"].Hash
            candidate_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $dataCandidate).Hash.ToLowerInvariant()
            bytes = (Get-Item -LiteralPath $dataCandidate).Length
            target_entries = @("MACHIN_3.DAT", "MACHIN_3.PAL")
            expected_observation = "repeating magenta/green tiles on the 18:00-and-later town map"
            compatibility = "original_engine_unverified"
        },
        [ordered]@{
            kind = "ogg_no_reencode_swap"
            path = "candidates/voice.arc"
            source_sha256 = $sourceSnapshot["voice.arc"].Hash
            candidate_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $voiceCandidate).Hash.ToLowerInvariant()
            bytes = (Get-Item -LiteralPath $voiceCandidate).Length
            target_entries = @("D0977.OGG")
            donor_entry = "D1033.OGG"
            expected_observation = "D1033 donor voice is heard at the first D0977 EVENTD03 marker"
            compatibility = "original_engine_unverified"
        }
    )
    $manifest = [ordered]@{
        schema = $Schema
        status = "prepared_unverified"
        created_utc = [DateTime]::UtcNow.ToString("o")
        launcher_sha256 = $sourceSnapshot["AI5WIN.original.exe"].Hash
        launches_original_engine = $false
        source_unchanged = $true
        candidates = $candidates
    }
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText(
        (Join-Path $stagingRoot "manifest.json"),
        (($manifest | ConvertTo-Json -Depth 8) + "`n"),
        $utf8
    )
    $instructions = @"
# Deferred original-engine verification candidates

Status: prepared only. No original engine or Godot GUI was launched.

- Use `prepare_local_verification_copy.ps1` to publish a separate disposable
  game copy, then replace only its matching ARC copies with `candidates/`.
- The local-copy preparer never launches the engine. Manual launch remains an
  explicit user action and may take keyboard focus while its window is active.
- Confirm the three `expected_observation` values in `manifest.json`.
- Do not copy original game data, screenshots, or machine paths into Git.
"@
    [IO.File]::WriteAllText(
        (Join-Path $stagingRoot "README.md"),
        $instructions.Replace("`n", "`r`n"),
        $utf8
    )
    Move-Item -LiteralPath $stagingRoot -Destination $resolvedOutputRoot
}
catch {
    $primaryError = $_
}
finally {
    try {
        Assert-SourceUnchanged -Paths $sourcePaths -Snapshot $sourceSnapshot
        Remove-StagingRoot `
            -Path $stagingRoot `
            -ExpectedParent $outputParent `
            -ExpectedPrefix $stagingPrefix
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

$manifestPath = Join-Path $resolvedOutputRoot "manifest.json"
$published = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Write-Output ((
    "ORIGINAL_ENGINE_BATCH_PREPARE_PASS schema={0} candidates={1} output={2} " +
    "launches_original_engine=false source_unchanged=true"
) -f $published.schema, $published.candidates.Count, $resolvedOutputRoot)
