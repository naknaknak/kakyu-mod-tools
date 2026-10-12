[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $GameRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $BatchRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputRoot,

    [switch] $PlanOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Schema = "kakyu_local_verification_copy/v1"
$ExpectedLauncherHash = "3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5"
$ExpectedBatchSchema = "kakyu_original_engine_verification_batch/v1"
$ExpectedCandidates = @{
    "mes.arc" = "a7452f24d355ef490acc9a3a635c36319680f58b9db2140731acc111590f210f"
    "data.arc" = "d93d615aa0146991603c640d928c7b2d0b528e5272f5592e20f3f3c3d5ebc581"
    "voice.arc" = "5875035d373f62b13b7d991734ef405b1c11378947e7e20838a734959dd78401"
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


function Get-Snapshot {
    param([string[]] $Paths)

    $snapshot = @{}
    foreach ($path in $Paths) {
        $item = Get-Item -LiteralPath $path
        $snapshot[$item.FullName] = [pscustomobject]@{
            Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToLowerInvariant()
            Length = $item.Length
            LastWriteTimeUtcTicks = $item.LastWriteTimeUtc.Ticks
        }
    }
    return $snapshot
}


function Assert-Unchanged {
    param([hashtable] $Snapshot)

    foreach ($path in $Snapshot.Keys) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Verification input disappeared: $path"
        }
        $item = Get-Item -LiteralPath $path
        $expected = $Snapshot[$path]
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
        if ($hash -ne $expected.Hash -or
            $item.Length -ne $expected.Length -or
            $item.LastWriteTimeUtc.Ticks -ne $expected.LastWriteTimeUtcTicks) {
            throw "Verification input changed during preparation: $path"
        }
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


$resolvedGameRoot = [IO.Path]::GetFullPath($GameRoot).TrimEnd("\")
$resolvedBatchRoot = [IO.Path]::GetFullPath($BatchRoot).TrimEnd("\")
$resolvedOutputRoot = [IO.Path]::GetFullPath($OutputRoot).TrimEnd("\")
if (-not (Test-Path -LiteralPath $resolvedGameRoot -PathType Container)) {
    throw "Game root does not exist: $resolvedGameRoot"
}
if (-not (Test-Path -LiteralPath $resolvedBatchRoot -PathType Container)) {
    throw "Prepared candidate batch does not exist: $resolvedBatchRoot"
}
if (Test-Path -LiteralPath $resolvedOutputRoot) {
    throw "Local verification output already exists: $resolvedOutputRoot"
}
if ((Test-IsBelow -Candidate $resolvedOutputRoot -Parent $resolvedGameRoot) -or
    (Test-IsBelow -Candidate $resolvedOutputRoot -Parent $resolvedBatchRoot) -or
    [string]::Equals($resolvedOutputRoot, $resolvedGameRoot, [StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($resolvedOutputRoot, $resolvedBatchRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Verification output must be outside the source game and candidate batch."
}
$outputParent = [IO.Path]::GetDirectoryName($resolvedOutputRoot)
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
    throw "Verification output parent does not exist: $outputParent"
}

$launcherPath = Join-Path $resolvedGameRoot "AI5WIN.original.exe"
$sourceElfImage = Join-Path $resolvedGameRoot "ELFIMAGE"
$iniPath = Join-Path $sourceElfImage "AI5WIN.INI"
if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $iniPath -PathType Leaf)) {
    throw "The game root must contain AI5WIN.original.exe and ELFIMAGE\AI5WIN.INI."
}
$sourceArchives = @(Get-ChildItem -LiteralPath $sourceElfImage -Filter "*.arc" -File)
if ($sourceArchives.Count -ne 8) {
    throw "The checked game root must contain exactly eight ELFIMAGE ARC files."
}
$launcherHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $launcherPath).Hash.ToLowerInvariant()
if ($launcherHash -ne $ExpectedLauncherHash) {
    throw "Original launcher identity does not match the checked verification target."
}

$batchManifestPath = Join-Path $resolvedBatchRoot "manifest.json"
if (-not (Test-Path -LiteralPath $batchManifestPath -PathType Leaf)) {
    throw "Prepared candidate manifest is missing."
}
$batchManifestText = Get-Content -LiteralPath $batchManifestPath -Raw
if ($batchManifestText.Contains("C:\") -or $batchManifestText.Contains("D:\")) {
    throw "Prepared candidate manifest must not contain absolute Windows paths."
}
$batchManifest = $batchManifestText | ConvertFrom-Json
if ($batchManifest.schema -ne $ExpectedBatchSchema -or
    $batchManifest.status -ne "prepared_unverified" -or
    $batchManifest.launches_original_engine -ne $false -or
    $batchManifest.source_unchanged -ne $true -or
    $batchManifest.launcher_sha256 -ne $ExpectedLauncherHash -or
    $batchManifest.candidates.Count -ne 3) {
    throw "Prepared candidate manifest contract does not match the checked batch."
}

$candidatePaths = @{}
foreach ($name in $ExpectedCandidates.Keys) {
    $candidatePath = Join-Path $resolvedBatchRoot ("candidates\" + $name)
    if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
        throw "Prepared candidate is missing: $name"
    }
    $candidateHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidatePath).Hash.ToLowerInvariant()
    if ($candidateHash -ne $ExpectedCandidates[$name]) {
        throw "Prepared candidate hash mismatch: $name"
    }
    $candidatePaths[$name] = $candidatePath
}

$optionalPaths = New-Object System.Collections.Generic.List[string]
foreach ($optionalName in @("ddraw.dll", "DDrawCompat.ini", "DDrawCompat-AI5WIN.ini")) {
    $optionalPath = Join-Path $resolvedGameRoot $optionalName
    if (Test-Path -LiteralPath $optionalPath -PathType Leaf) {
        $optionalPaths.Add($optionalPath)
    }
}
$savePaths = New-Object System.Collections.Generic.List[string]
$sourceSave = Join-Path $sourceElfImage "save"
if (Test-Path -LiteralPath $sourceSave -PathType Container) {
    Get-ChildItem -LiteralPath $sourceSave -File |
        Where-Object { $_.Name -match "^FLAG\d\d$" -or $_.Name -eq "MesSkip.dat" } |
        ForEach-Object { $savePaths.Add($_.FullName) }
}

$snapshotPaths = New-Object System.Collections.Generic.List[string]
$snapshotPaths.Add($launcherPath)
$snapshotPaths.Add($iniPath)
foreach ($archive in $sourceArchives) { $snapshotPaths.Add($archive.FullName) }
foreach ($path in $optionalPaths) { $snapshotPaths.Add($path) }
foreach ($path in $savePaths) { $snapshotPaths.Add($path) }
$snapshotPaths.Add($batchManifestPath)
foreach ($candidatePath in $candidatePaths.Values) { $snapshotPaths.Add($candidatePath) }
$inputSnapshot = Get-Snapshot -Paths $snapshotPaths.ToArray()

$requiredBytes = 8MB
$requiredBytes += (Get-Item -LiteralPath $launcherPath).Length
$requiredBytes += (Get-Item -LiteralPath $iniPath).Length
foreach ($archive in $sourceArchives) {
    $requiredBytes += $archive.Length
}
foreach ($path in $optionalPaths) {
    $requiredBytes += (Get-Item -LiteralPath $path).Length
}
foreach ($path in $savePaths) {
    $requiredBytes += (Get-Item -LiteralPath $path).Length
}
$outputDrive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($resolvedOutputRoot))
if (-not $PlanOnly -and $outputDrive.AvailableFreeSpace -lt $requiredBytes) {
    throw "Insufficient output-drive space: $($outputDrive.AvailableFreeSpace) < $requiredBytes bytes"
}

if ($PlanOnly) {
    Assert-Unchanged -Snapshot $inputSnapshot
    Write-Output ((
        "LOCAL_VERIFICATION_COPY_PREFLIGHT_PASS schema={0} required_bytes={1} " +
        "launches_original_engine=false source_unchanged=true"
    ) -f $Schema, $requiredBytes)
    exit 0
}

$outputLeaf = [IO.Path]::GetFileName($resolvedOutputRoot)
$stagingPrefix = $outputLeaf + ".staging-"
$stagingRoot = Join-Path $outputParent ($stagingPrefix + [guid]::NewGuid().ToString("N"))
$primaryError = $null

try {
    $destinationElfImage = Join-Path $stagingRoot "ELFIMAGE"
    $destinationSave = Join-Path $destinationElfImage "save"
    New-Item -ItemType Directory -Path $destinationSave -Force | Out-Null
    Copy-Item -LiteralPath $launcherPath -Destination (Join-Path $stagingRoot "AI5WIN.exe")
    foreach ($path in $optionalPaths) {
        Copy-Item -LiteralPath $path -Destination $stagingRoot
    }
    Copy-Item -LiteralPath $iniPath -Destination $destinationElfImage
    foreach ($archive in $sourceArchives) {
        Copy-Item -LiteralPath $archive.FullName -Destination $destinationElfImage
    }
    foreach ($path in $savePaths) {
        Copy-Item -LiteralPath $path -Destination $destinationSave
    }
    foreach ($name in $ExpectedCandidates.Keys) {
        Copy-Item `
            -LiteralPath $candidatePaths[$name] `
            -Destination (Join-Path $destinationElfImage $name) `
            -Force
    }

    $copiedLauncher = Join-Path $stagingRoot "AI5WIN.exe"
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $copiedLauncher).Hash.ToLowerInvariant() -ne $ExpectedLauncherHash) {
        throw "Copied launcher hash mismatch."
    }
    foreach ($archive in $sourceArchives) {
        $destinationArchive = Join-Path $destinationElfImage $archive.Name
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationArchive).Hash.ToLowerInvariant()
        if ($ExpectedCandidates.ContainsKey($archive.Name)) {
            if ($actual -ne $ExpectedCandidates[$archive.Name]) {
                throw "Copied candidate hash mismatch: $($archive.Name)"
            }
        }
        elseif ($actual -ne $inputSnapshot[$archive.FullName].Hash) {
            throw "Copied source archive hash mismatch: $($archive.Name)"
        }
    }

    $utf8 = New-Object Text.UTF8Encoding($false)
    $manifest = [ordered]@{
        schema = $Schema
        status = "prepared_not_launched"
        created_utc = [DateTime]::UtcNow.ToString("o")
        launches_original_engine = $false
        source_unchanged = $true
        launcher_sha256 = $ExpectedLauncherHash
        candidate_batch_schema = $ExpectedBatchSchema
        candidate_hashes = $ExpectedCandidates
        executable = "AI5WIN.exe"
    }
    [IO.File]::WriteAllText(
        (Join-Path $stagingRoot "verification_manifest.json"),
        (($manifest | ConvertTo-Json -Depth 6) + "`n"),
        $utf8
    )
    $instructions = @"
# Kakyu disposable local verification copy

Status: prepared only. No original engine or Godot GUI was launched.

- This directory is a disposable copy. The source installation was rehashed
  after publication and was not modified.
- Close unrelated applications before manually opening `AI5WIN.exe`; the old
  engine may take keyboard focus while its window is active.
- Confirm the three `expected_observation` values in the candidate batch
  `manifest.json`, then close the copied engine.
- Delete this entire directory when observation is complete.
- Do not add this directory, original data, screenshots, or machine paths to Git.
"@
    [IO.File]::WriteAllText(
        (Join-Path $stagingRoot "README.md"),
        $instructions.Replace("`n", "`r`n"),
        $utf8
    )
    Assert-Unchanged -Snapshot $inputSnapshot
    Move-Item -LiteralPath $stagingRoot -Destination $resolvedOutputRoot
}
catch {
    $primaryError = $_
}
finally {
    try {
        Assert-Unchanged -Snapshot $inputSnapshot
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
            Write-Warning "Additional cleanup or input-integrity failure: $_"
        }
    }
}

if ($null -ne $primaryError) {
    throw $primaryError
}

Write-Output ((
    "LOCAL_VERIFICATION_COPY_PREPARE_PASS schema={0} output={1} " +
    "launches_original_engine=false source_unchanged=true"
) -f $Schema, $resolvedOutputRoot)
