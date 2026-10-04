param([Parameter(Mandatory = $true)][string]$Path)

$ErrorActionPreference = "Stop"
$resolved = (Resolve-Path -LiteralPath $Path).Path
$zip = $null
$root = $null

if (Test-Path -LiteralPath $resolved -PathType Container) {
    $root = $resolved
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($resolved)
}

function Normalize([string]$asset) { $asset.TrimStart('/').Replace('\', '/') }
function Exists([string]$asset) {
    $asset = Normalize $asset
    if ($null -ne $root) {
        return Test-Path -LiteralPath (Join-Path $root $asset.Replace('/', [IO.Path]::DirectorySeparatorChar)) -PathType Leaf
    }
    return $null -ne $zip.GetEntry($asset)
}
function ReadText([string]$asset) {
    $asset = Normalize $asset
    if ($null -ne $root) {
        return [IO.File]::ReadAllText((Join-Path $root $asset.Replace('/', [IO.Path]::DirectorySeparatorChar)))
    }
    $entry = $zip.GetEntry($asset)
    if ($null -eq $entry) { throw "Missing asset: $asset" }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

$failures = [Collections.Generic.List[string]]::new()
function Require([bool]$condition, [string]$message) {
    if (-not $condition) { $failures.Add($message) }
}

try {
    Require (Exists "manifest.sii") "Missing manifest.sii"
    if (Exists "manifest.sii") {
        Require ((ReadText "manifest.sii") -match 'compatible_versions\[\]\s*:\s*"1\.59\.\*"') "manifest.sii does not declare ETS2 1.59.* compatibility"
    }

    $defs = @(
        @{ File = "optical_hud.sii"; Unit = "optical_hud.granbird.23.set_lglass" },
        @{ File = "optical_hud_large.sii"; Unit = "ohud_l.granbird.23.set_lglass" },
        @{ File = "optical_hud_extra_large.sii"; Unit = "ohud_xl.granbird.23.set_lglass" }
    )
    foreach ($def in $defs) {
        $path = "def/vehicle/truck/granbird.23/accessory/set_lglass/$($def.File)"
        Require (Exists $path) "Missing Grandbird HUD definition: $path"
        if (-not (Exists $path)) { continue }
        $text = ReadText $path
        Require ($text -match [regex]::Escape("accessory_addon_int_ui_data : $($def.Unit)")) "Wrong unit name in $path"
        foreach ($key in @("interior_model", "ui_path", "ui_drawable_texture_path")) {
            $match = [regex]::Match($text, "(?m)^\s*$key\s*:\s*`"([^`"]+)`"")
            Require $match.Success "Missing $key in $path"
            if ($match.Success) {
                $asset = $match.Groups[1].Value
                Require (Exists $asset) "$path references missing asset: $asset"
                if ($key -eq "interior_model") {
                    $pmg = [IO.Path]::ChangeExtension($asset, ".pmg").Replace('\', '/')
                    Require (Exists $pmg) "$path has no matching PMG: $pmg"
                }
            }
        }
    }

    $uiPath = "ui/dashboard/optical_hud.sii"
    Require (Exists $uiPath) "Missing HUD UI"
    if (Exists $uiPath) {
        $ui = ReadText $uiPath
        Require ($ui -match '(?m)^\s*id\s*:\s*1020\s*$') "HUD UI is missing current-speed ID 1020"
        Require ($ui -match '(?m)^\s*id\s*:\s*1610\s*$') "HUD UI is missing speed-limit ID 1610"
        Require ($ui -match '/material/ui/dashboard/bare_map\.mat') "HUD UI is missing GPS map data"
    }
    Require (Exists "ui/template/dashboard_text.optical_hud.sii") "Missing HUD text template"
    Require (Exists "vehicle/truck/share/optical_hud.tobj") "Missing render texture descriptor"
    Require (Exists "vehicle/truck/share/optical_hud.dds") "Missing render texture"
    Require (Exists "automat/a5/a5ae7b4d9051a340.mat") "Missing converted HUD material"

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "PASS: Grandbird HUD addon is structurally valid for ETS2 1.59."
} finally {
    if ($null -ne $zip) { $zip.Dispose() }
}
