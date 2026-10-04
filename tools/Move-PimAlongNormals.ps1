param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][double]$Distance
)

$ErrorActionPreference = 'Stop'

function Float-FromHex([string]$hex) {
    $bits = [Convert]::ToUInt32($hex, 16)
    return [BitConverter]::ToSingle([BitConverter]::GetBytes($bits), 0)
}

function Hex-FromFloat([single]$value) {
    $bits = [BitConverter]::ToUInt32([BitConverter]::GetBytes($value), 0)
    return $bits.ToString('x8')
}

$resolved = (Resolve-Path -LiteralPath $Path).Path
$text = [IO.File]::ReadAllText($resolved)
$streamPattern = '(?s)Stream\s*\{\s*Format:\s*FLOAT3\s*Tag:\s*"{0}"(.*?)(?=\r?\n\s*\})'
$positionMatch = [regex]::Match($text, $streamPattern.Replace('{0}', '_POSITION'))
$normalMatch = [regex]::Match($text, $streamPattern.Replace('{0}', '_NORMAL'))
if (-not $positionMatch.Success -or -not $normalMatch.Success) { throw 'PIM must contain _POSITION and _NORMAL FLOAT3 streams.' }

$triplePattern = '\(\s*&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s*\)'
$positions = @([regex]::Matches($positionMatch.Groups[1].Value, $triplePattern))
$normals = @([regex]::Matches($normalMatch.Groups[1].Value, $triplePattern))
if ($positions.Count -eq 0 -or $positions.Count -ne $normals.Count) { throw 'Position/normal vertex count mismatch.' }

$index = 0
$newPositionBody = [regex]::Replace($positionMatch.Groups[1].Value, $triplePattern, {
    param($match)
    $normal = $normals[$index]
    $values = for ($axis = 1; $axis -le 3; $axis++) {
        [single]((Float-FromHex $match.Groups[$axis].Value) + ((Float-FromHex $normal.Groups[$axis].Value) * $Distance))
    }
    $index++
    return '( &' + (Hex-FromFloat $values[0]) + '  &' + (Hex-FromFloat $values[1]) + '  &' + (Hex-FromFloat $values[2]) + ' )'
})

$updated = $text.Substring(0, $positionMatch.Groups[1].Index) + $newPositionBody + $text.Substring($positionMatch.Groups[1].Index + $positionMatch.Groups[1].Length)
$updated = $updated.Replace('eut2.dif.lum.a', 'eut2.dif.lum.add')
[IO.File]::WriteAllText($resolved, $updated, [Text.UTF8Encoding]::new($false))

Write-Host "Moved $($positions.Count) vertices by $Distance m along their normals: $Path"
