param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$BaselineRoot
)

$ErrorActionPreference = "Stop"
$failures = [Collections.Generic.List[string]]::new()
function Require([bool]$condition, [string]$message) { if (-not $condition) { $failures.Add($message) } }

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "FAIL: Candidate package does not exist: $Path" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $BaselineRoot -PathType Container)) {
    Write-Host "FAIL: Baseline root does not exist: $BaselineRoot" -ForegroundColor Red
    exit 1
}

$resolved = (Resolve-Path -LiteralPath $Path).Path
$baseline = (Resolve-Path -LiteralPath $BaselineRoot).Path
$zip = $null
$root = $null
if (Test-Path -LiteralPath $resolved -PathType Container) {
    $root = $resolved
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($resolved)
}

function NormalizePath([string]$asset) { $asset.TrimStart('/').Replace('\', '/') }
function Entries {
    if ($null -ne $root) {
        return Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') }
    }
    return $zip.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) } | ForEach-Object { $_.FullName }
}
function Exists([string]$asset) {
    $asset = NormalizePath $asset
    if ($null -ne $root) { return Test-Path -LiteralPath (Join-Path $root $asset.Replace('/', [IO.Path]::DirectorySeparatorChar)) -PathType Leaf }
    return $null -ne $zip.GetEntry($asset)
}
function ReadText([string]$asset) {
    $asset = NormalizePath $asset
    if ($null -ne $root) { return [IO.File]::ReadAllText((Join-Path $root $asset.Replace('/', [IO.Path]::DirectorySeparatorChar))) }
    $entry = $zip.GetEntry($asset)
    if ($null -eq $entry) { throw "Missing asset: $asset" }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function NormalizeDefinition([string]$text, [bool]$removeFixFields) {
    $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    if ($removeFixFields) {
        $normalized = [regex]::Replace($normalized, '(?m)^\s*master_collision_angle\s*:\s*180(?:\.0+)?\s*\n', '')
    }
    $lines = $normalized.Split("`n") | ForEach-Object { $_.TrimEnd() }
    return ($lines -join "`n").TrimEnd()
}

try {
    $entries = @(Entries)
    Require (($entries | Where-Object { $_ -match '\\' }).Count -eq 0) "Package contains backslash archive paths"
    Require (($entries | Select-Object -Unique).Count -eq $entries.Count) "Package contains duplicate paths"
    Require (($entries | Where-Object { $_ -match '^def/vehicle/truck/' }).Count -eq 0) "Trailer fix contains truck definitions"
    Require (($entries | Where-Object { $_ -match '(?i)\.(pmd|pmg|pmc|scs)$' }).Count -eq 0) "Trailer fix contains model or nested mod assets"

    Require (Exists "manifest.sii") "Missing manifest.sii"
    if (Exists "manifest.sii") {
        $manifest = ReadText "manifest.sii"
        Require ($manifest -match 'package_version\s*:\s*"1\.2"') "Manifest package version is not 1.2"
        Require ($manifest -match 'compatible_versions\[\]\s*:\s*"1\.59\.\*"') "Manifest does not declare ETS2 1.59.*"
    }
    Require (Exists "description.txt") "Missing description.txt"
    if (Exists "description.txt") {
        $description = ReadText "description.txt"
        Require ($description -match '(?is)higher\s+priority.*bus') "Description omits higher-priority installation guidance"
        Require ($description -match '(?is)fresh\s+passenger\s+job') "Description omits fresh passenger-job guidance"
        Require ($description -match '(?is)restores?\s+the\s+valid\s+invisible\s+trailer\s+collision') "Description omits collision-restoration guidance"
        Require ($description -match '(?is)Kim\s+Long.*only\s+if.*passenger.*crsthn\.t_passag') "Description omits conditional Kim Long coverage"
    }

    $definitions = [ordered]@{
        "def/vehicle/trailer_owned/passenger/chassis/chassis.sii" = "chs.passenger.chassis"
        "def/vehicle/trailer_owned/crsthn.t_passag/chassis/chassis.sii" = "chs.crsthn.t_passag.chassis"
    }
    foreach ($asset in $definitions.Keys) {
        Require (Exists $asset) "Missing trailer override: $asset"
        if (-not (Exists $asset)) { continue }
        $candidate = ReadText $asset
        Require ($candidate -match [regex]::Escape("accessory_chassis_data : $($definitions[$asset])")) "Wrong chassis unit in $asset"
        Require (([regex]::Matches($candidate, '(?m)^\s*master_collision_angle\s*:\s*180(?:\.0+)?\s*$')).Count -eq 1) "$asset must contain exactly one master_collision_angle: 180"
        Require (([regex]::Matches($candidate, '(?m)^\s*collision\s*:\s*"/vehicle/trailer_owned/crs_trailer_inv/trailer_invisivel\.pmc"\s*$')).Count -eq 1) "$asset must use the valid invisible trailer collision PMC"
        Require ($candidate -notmatch '(?m)^\s*collision\s*:\s*""\s*$') "$asset contains an invalid blank collision path"
        Require (([regex]::Matches($candidate, '(?m)^\s*residual_travel\[\]\s*:')).Count -eq 2) "$asset no longer has two suspension travel entries"
        Require (([regex]::Matches($candidate, '(?m)^\s*steerable_axle\[\]\s*:')).Count -eq 2) "$asset no longer has two steerable axle entries"
        Require ($candidate -match '(?m)^\s*trailer_mass\s*:\s*100\s*$') "$asset changed trailer mass"
        foreach ($field in @('cog_cargo_mass_min','cog_cargo_mass_max','cog_cargo_offset_min','cog_cargo_offset_max')) {
            Require ($candidate -match "(?m)^\s*$field\s*:") "$asset is missing $field"
        }

        $baselineFile = Join-Path $baseline $asset.Replace('/', [IO.Path]::DirectorySeparatorChar)
        Require (Test-Path -LiteralPath $baselineFile -PathType Leaf) "Missing baseline definition: $baselineFile"
        if (Test-Path -LiteralPath $baselineFile -PathType Leaf) {
            $baselineText = [IO.File]::ReadAllText($baselineFile)
            Require ((NormalizeDefinition $candidate $true) -ceq (NormalizeDefinition $baselineText $false)) "$asset changed fields beyond master_collision_angle"
        }
    }

    $actualDefs = $entries | Where-Object { $_ -match '^def/vehicle/trailer_owned/.+/chassis/.+\.sii$' } | Sort-Object
    Require (($actualDefs -join '|') -ceq (($definitions.Keys | Sort-Object) -join '|')) "Package trailer definitions differ from the approved two: $($actualDefs -join ', ')"

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "PASS: passenger trailer fix preserves both baselines, uses a valid collision path, and changes only master_collision_angle."
} finally {
    if ($null -ne $zip) { $zip.Dispose() }
}
