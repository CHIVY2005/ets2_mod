param(
    [Parameter(Mandatory = $true)][string]$Original,
    [Parameter(Mandatory = $true)][string]$Transformed,
    [Parameter(Mandatory = $true)][double]$ExpectedOffset
)

$ErrorActionPreference = "Stop"
$failures = [Collections.Generic.List[string]]::new()

function Fail([string]$message) { $failures.Add($message) }
function Decode-Float([string]$hex) {
    $bits = [Convert]::ToUInt32($hex, 16)
    return [BitConverter]::ToSingle([BitConverter]::GetBytes($bits), 0)
}
function Get-PositionData([string]$path) {
    $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).Path)
    $blockMatch = [regex]::Match($text, '(?s)(Tag:\s*"_POSITION".*?)(?=\r?\n\s*Stream\s*\{)')
    if (-not $blockMatch.Success) { throw "No _POSITION stream found in $path" }
    $triplePattern = '\(\s*&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s*\)'
    $triples = [regex]::Matches($blockMatch.Groups[1].Value, $triplePattern)
    if ($triples.Count -eq 0) { throw "No position triples found in $path" }
    $maskedBlock = [regex]::Replace(
        $blockMatch.Groups[1].Value,
        '(\(\s*)&[0-9a-fA-F]{8}(\s+&[0-9a-fA-F]{8}\s+&[0-9a-fA-F]{8}\s*\))',
        '${1}&XXXXXXXX${2}'
    )
    return [pscustomobject]@{
        Text = $text
        Block = $blockMatch.Groups[1].Value
        BlockIndex = $blockMatch.Groups[1].Index
        Triples = $triples
        MaskedText = $text.Substring(0, $blockMatch.Groups[1].Index) + $maskedBlock + $text.Substring($blockMatch.Groups[1].Index + $blockMatch.Groups[1].Length)
    }
}

if (-not (Test-Path -LiteralPath $Original -PathType Leaf)) { Fail "Original PIM does not exist: $Original" }
if (-not (Test-Path -LiteralPath $Transformed -PathType Leaf)) { Fail "Transformed PIM does not exist: $Transformed" }

if ($failures.Count -eq 0) {
    try {
        $before = Get-PositionData $Original
        $after = Get-PositionData $Transformed
        if ($before.Triples.Count -ne $after.Triples.Count) {
            Fail "Vertex count changed: $($before.Triples.Count) -> $($after.Triples.Count)"
        } else {
            for ($i = 0; $i -lt $before.Triples.Count; $i++) {
                $bx = Decode-Float $before.Triples[$i].Groups[1].Value
                $by = Decode-Float $before.Triples[$i].Groups[2].Value
                $bz = Decode-Float $before.Triples[$i].Groups[3].Value
                $ax = Decode-Float $after.Triples[$i].Groups[1].Value
                $ay = Decode-Float $after.Triples[$i].Groups[2].Value
                $az = Decode-Float $after.Triples[$i].Groups[3].Value
                if ([math]::Abs(($ax - $bx) - $ExpectedOffset) -gt 0.00001) { Fail "Vertex $i X offset is $($ax - $bx), expected $ExpectedOffset" }
                if ([math]::Abs($ay - $by) -gt 0.000001) { Fail "Vertex $i Y changed" }
                if ([math]::Abs($az - $bz) -gt 0.000001) { Fail "Vertex $i Z changed" }
            }
        }
        if ($before.MaskedText -cne $after.MaskedText) { Fail "Content outside X position tokens changed" }
    } catch {
        Fail $_.Exception.Message
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    exit 1
}
Write-Host "PASS: PIM X positions moved by $ExpectedOffset and all other content is unchanged."

