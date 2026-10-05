$ErrorActionPreference = 'Stop'
$failures = [Collections.Generic.List[string]]::new()

function Float-FromHex([string]$hex) {
    $bits = [Convert]::ToUInt32($hex, 16)
    return [BitConverter]::ToSingle([BitConverter]::GetBytes($bits), 0)
}

function Center([string]$path) {
    $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).Path)
    $block = [regex]::Match($text, '(?s)Tag:\s*"_POSITION"(.*?)(?=\r?\n\s*Stream\s*\{)')
    if (-not $block.Success) { throw "Missing _POSITION stream: $path" }
    $vertices = [regex]::Matches($block.Groups[1].Value, '\(\s*&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s*\)')
    if ($vertices.Count -eq 0) { throw "No vertices: $path" }
    $values = @()
    foreach ($axis in 1..3) { $values += ,@($vertices | ForEach-Object { Float-FromHex ($_.Groups[$axis].Value) }) }
    return [pscustomobject]@{
        X = (($values[0] | Measure-Object -Minimum -Maximum).Minimum + ($values[0] | Measure-Object -Minimum -Maximum).Maximum) / 2
        Y = (($values[1] | Measure-Object -Minimum -Maximum).Minimum + ($values[1] | Measure-Object -Minimum -Maximum).Maximum) / 2
        Z = (($values[2] | Measure-Object -Minimum -Maximum).Minimum + ($values[2] | Measure-Object -Minimum -Maximum).Maximum) / 2
    }
}

foreach ($family in @('kia', 'kimlong', 'thaco')) {
    $hud = Center "src/hud_model_sources/$family/optical_hud.pim"
    $dashboard = Center "src/hud_model_sources/$family/dashboard_gps.pim"
    if ([math]::Abs(($dashboard.X - $hud.X) - 0.65) -gt 0.0001) { $failures.Add("$family dashboard horizontal placement is wrong") }
    # Keep the screen on the HUD viewing axis: HUD normal slope (0.0685 / 0.9099) x 2.60 depth shift ~= +0.20.
    if ([math]::Abs(($dashboard.Y - $hud.Y) - 0.20) -gt 0.0001) { $failures.Add("$family dashboard is not raised onto the HUD line of sight") }
    if ([math]::Abs(($dashboard.Z - $hud.Z) - 2.60) -gt 0.0001) { $failures.Add("$family dashboard depth placement is wrong") }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'PASS: dashboard GPS models are centered, raised above the dashboard, and closer to the cabin.'
