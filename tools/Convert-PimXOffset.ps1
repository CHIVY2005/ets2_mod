param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][double]$Offset,
    [ValidateSet('X', 'Y', 'Z')][string]$Axis = 'X'
)

$ErrorActionPreference = "Stop"
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$text = [IO.File]::ReadAllText($sourcePath)
$blockMatch = [regex]::Match($text, '(?s)(Tag:\s*"_POSITION".*?)(?=\r?\n\s*Stream\s*\{)')
if (-not $blockMatch.Success) { throw "No _POSITION stream found in $Source" }

$triplePattern = '(\(\s*)&([0-9a-fA-F]{8})(\s+)&([0-9a-fA-F]{8})(\s+)&([0-9a-fA-F]{8})(\s*\))'
$axisGroup = @{ X = 2; Y = 4; Z = 6 }[$Axis]
$changed = 0
$rewrittenBlock = [regex]::Replace(
    $blockMatch.Groups[1].Value,
    $triplePattern,
    [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $parts = @(1..7 | ForEach-Object { $match.Groups[$_].Value })
        $bits = [Convert]::ToUInt32($parts[$axisGroup - 1], 16)
        $value = [BitConverter]::ToSingle([BitConverter]::GetBytes($bits), 0)
        $newValue = [single]($value + $Offset)
        $newBits = [BitConverter]::ToUInt32([BitConverter]::GetBytes($newValue), 0)
        $parts[$axisGroup - 1] = $newBits.ToString('x8')
        $script:changed++
        return $parts[0] + '&' + $parts[1] + $parts[2] + '&' + $parts[3] + $parts[4] + '&' + $parts[5] + $parts[6]
    }
)
if ($changed -eq 0) { throw "No position vertices were rewritten in $Source" }

$rewritten = $text.Substring(0, $blockMatch.Groups[1].Index) + $rewrittenBlock + $text.Substring($blockMatch.Groups[1].Index + $blockMatch.Groups[1].Length)
$destinationFull = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Destination))
$destinationDirectory = [IO.Path]::GetDirectoryName($destinationFull)
if (-not [string]::IsNullOrEmpty($destinationDirectory)) {
    [IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
}
[IO.File]::WriteAllText($destinationFull, $rewritten, [Text.UTF8Encoding]::new($false))
Write-Host "Converted $changed vertices with $Axis offset $Offset -> $destinationFull"
