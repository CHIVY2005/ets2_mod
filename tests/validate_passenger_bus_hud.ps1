param([Parameter(Mandatory = $true)][string]$Path)

$ErrorActionPreference = "Stop"
$resolved = (Resolve-Path -LiteralPath $Path).Path
$zip = $null
$root = $null
$failures = [Collections.Generic.List[string]]::new()

if (Test-Path -LiteralPath $resolved -PathType Container) {
    $root = $resolved
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($resolved)
}

function Normalize([string]$asset) { $asset.TrimStart('/').Replace('\', '/') }
function Entries {
    if ($null -ne $root) {
        return Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') }
    }
    return $zip.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) } | ForEach-Object { $_.FullName }
}
function Exists([string]$asset) {
    $asset = Normalize $asset
    if ($null -ne $root) { return Test-Path -LiteralPath (Join-Path $root $asset.Replace('/', [IO.Path]::DirectorySeparatorChar)) -PathType Leaf }
    return $null -ne $zip.GetEntry($asset)
}
function ReadText([string]$asset) {
    $asset = Normalize $asset
    if ($null -ne $root) { return [IO.File]::ReadAllText((Join-Path $root $asset.Replace('/', [IO.Path]::DirectorySeparatorChar))) }
    $entry = $zip.GetEntry($asset)
    if ($null -eq $entry) { throw "Missing asset: $asset" }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Require([bool]$condition, [string]$message) { if (-not $condition) { $failures.Add($message) } }

try {
    $entries = @(Entries)
    Require (($entries | Where-Object { $_ -match '\\' }).Count -eq 0) "Package contains backslash archive paths"
    Require (($entries | Select-Object -Unique).Count -eq $entries.Count) "Package contains duplicate paths"
    Require (($entries | Where-Object { $_ -match '(?i)\.(pim|pit)$' }).Count -eq 0) "Package contains intermediate PIM/PIT files"
    Require (($entries | Where-Object { $_ -match '(?i)\.scs$' }).Count -eq 0) "Package contains a nested vehicle/mod archive"

    Require (Exists "manifest.sii") "Missing manifest.sii"
    if (Exists "manifest.sii") {
        $manifest = ReadText "manifest.sii"
        Require ($manifest -match 'package_version\s*:\s*"1\.2"') "Manifest package version is not 1.2"
        Require ($manifest -match 'compatible_versions\[\]\s*:\s*"1\.59\.\*"') "Manifest does not declare ETS2 1.59.*"
    }

    $truckFamilies = [ordered]@{
        "granbird.23" = "kia"
        "kimlong.99" = "kimlong"
        "thaco.mbh.23" = "thaco"
        "thaco.mbh.25" = "thaco"
        "man.tgx.sample" = "thaco"
    }
    $sizes = @(
        @{ File = "optical_hud.sii"; Unit = "optical_hud"; Model = "optical_hud" },
        @{ File = "optical_hud_large.sii"; Unit = "ohud_l"; Model = "optical_hud_large" },
        @{ File = "optical_hud_extra_large.sii"; Unit = "ohud_xl"; Model = "optical_hud_extra_large" }
    )
    $units = [Collections.Generic.List[string]]::new()
    foreach ($truck in $truckFamilies.Keys) {
        $family = $truckFamilies[$truck]
        foreach ($size in $sizes) {
            $defPath = "def/vehicle/truck/$truck/accessory/set_lglass/$($size.File)"
            Require (Exists $defPath) "Missing HUD definition: $defPath"
            if (-not (Exists $defPath)) { continue }
            $text = ReadText $defPath
            $expectedUnit = "$($size.Unit).$truck.set_lglass"
            $unitMatch = [regex]::Match($text, 'accessory_addon_int_ui_data\s*:\s*([^\s\r\n]+)')
            Require $unitMatch.Success "Missing accessory unit in $defPath"
            if ($unitMatch.Success) {
                Require ($unitMatch.Groups[1].Value -ceq $expectedUnit) "Wrong unit in ${defPath}: $($unitMatch.Groups[1].Value)"
                $units.Add($unitMatch.Groups[1].Value)
            }
            $model = "/vehicle/truck/passenger_hud/$family/$($size.Model).pmd"
            Require ($text -match [regex]::Escape("interior_model: `"$model`"")) "$defPath does not use family model $model"
            Require (Exists $model) "$defPath references missing PMD: $model"
            Require (Exists ([IO.Path]::ChangeExtension($model, '.pmg').Replace('\', '/'))) "$defPath references a model without PMG"
            Require ($text -match 'ui_path\s*:\s*"/ui/dashboard/optical_hud\.sii"') "$defPath uses the wrong UI path"
            Require ($text -match 'ui_drawable_texture_path\s*:\s*"/vehicle/truck/passenger_hud/share/hud_ui\.tobj"') "$defPath uses a non-unique drawable texture"
            Require ($text -match 'ui_drawable_size\s*:\s*\(1024,\s*1024\)') "$defPath drawable is not 1024 x 1024"
        }
    }
    Require (($units | Select-Object -Unique).Count -eq 15) "Accessory unit names are not 15 unique values"

    $actualTruckIds = $entries | Where-Object { $_ -match '^def/vehicle/truck/([^/]+)/' } | ForEach-Object { [regex]::Match($_, '^def/vehicle/truck/([^/]+)/').Groups[1].Value } | Sort-Object -Unique
    Require (($actualTruckIds -join '|') -ceq (($truckFamilies.Keys | Sort-Object) -join '|')) "Package truck IDs differ from the approved five: $($actualTruckIds -join ', ')"

    Require (Exists "ui/dashboard/optical_hud.sii") "Missing Optical HUD UI"
    if (Exists "ui/dashboard/optical_hud.sii") {
        $ui = ReadText "ui/dashboard/optical_hud.sii"
        Require ($ui -match '(?m)^\s*id\s*:\s*1020\s*$') "UI is missing current-speed ID 1020"
        Require ($ui -match '(?m)^\s*id\s*:\s*1610\s*$') "UI is missing speed-limit ID 1610"
        Require ($ui -match '/material/ui/dashboard/bare_map\.mat') "UI is missing the navigation map"
    }
    Require (Exists "ui/template/dashboard_text.optical_hud.sii") "Missing HUD text templates"
    if (Exists "ui/template/dashboard_text.optical_hud.sii") {
        $template = ReadText "ui/template/dashboard_text.optical_hud.sii"
        Require ($template -notmatch 'CCFFFFFF') "Secondary HUD text still uses partial alpha"
        Require ($template -match 'FFFFFFFF') "HUD template has no full-alpha white text"
    }
    Require (Exists "vehicle/truck/passenger_hud/share/hud_ui.tobj") "Missing unique HUD TOBJ"
    Require (Exists "vehicle/truck/passenger_hud/share/hud_ui.dds") "Missing HUD placeholder DDS"
    Require (($entries | Where-Object { $_ -match '^automat/.+\.mat$' }).Count -ge 1) "Missing converted HUD material"

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "PASS: passenger-bus HUD package supports five buses, 15 unique accessories, three model families, and ETS2 1.59."
} finally {
    if ($null -ne $zip) { $zip.Dispose() }
}
