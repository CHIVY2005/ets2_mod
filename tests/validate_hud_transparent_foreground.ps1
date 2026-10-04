param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$BaselinePackage,
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][string]$BaselineSourceRoot,
    [double]$Offset = 0.03
)

$ErrorActionPreference = 'Stop'
$failures = [Collections.Generic.List[string]]::new()

function Float-FromHex([string]$hex) {
    $bits = [Convert]::ToUInt32($hex, 16)
    return [BitConverter]::ToSingle([BitConverter]::GetBytes($bits), 0)
}

function Read-Stream([string]$text, [string]$tag) {
    $match = [regex]::Match($text, '(?s)Stream\s*\{\s*Format:\s*FLOAT3\s*Tag:\s*"' + [regex]::Escape($tag) + '"(.*?)(?=\r?\n\s*\})')
    if (-not $match.Success) { throw "Missing $tag stream" }
    return @([regex]::Matches($match.Groups[1].Value, '\(\s*&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s+&([0-9a-fA-F]{8})\s*\)') | ForEach-Object {
        [pscustomobject]@{
            X = Float-FromHex $_.Groups[1].Value
            Y = Float-FromHex $_.Groups[2].Value
            Z = Float-FromHex $_.Groups[3].Value
        }
    })
}

function Normalize-Pim([string]$text) {
    $normalized = $text.Replace("`r`n", "`n")
    $normalized = [regex]::Replace($normalized, 'Effect:\s*"eut2\.dif\.lum\.(?:a|add)"', 'Effect: "HUD_SHADER"')
    $position = [regex]::Match($normalized, '(?s)(Stream\s*\{\s*Format:\s*FLOAT3\s*Tag:\s*"_POSITION".*?)(?=\n\s*\})')
    if (-not $position.Success) { throw 'Missing _POSITION stream for normalization' }
    $masked = [regex]::Replace($position.Groups[1].Value, '&[0-9a-fA-F]{8}', '&XXXXXXXX')
    return $normalized.Substring(0, $position.Index) + $masked + $normalized.Substring($position.Index + $position.Length)
}

$pimFiles = @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Filter '*.pim' | Where-Object { $_.Name -match '^optical_hud(?:_large|_extra_large)?\.pim$' })
if ($pimFiles.Count -ne 9) { $failures.Add("Expected 9 PIM sources, found $($pimFiles.Count)") }

foreach ($candidateFile in $pimFiles) {
    $relative = $candidateFile.FullName.Substring((Resolve-Path -LiteralPath $SourceRoot).Path.Length + 1)
    $baselineFile = Join-Path $BaselineSourceRoot $relative
    $candidateText = [IO.File]::ReadAllText($candidateFile.FullName)
    $baselineText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $baselineFile).Path)
    if ($candidateText -notmatch 'Effect:\s*"eut2\.dif\.lum\.add"') {
        $failures.Add("$relative does not restore additive transparency")
    }
    $oldPosition = @(Read-Stream $baselineText '_POSITION')
    $newPosition = @(Read-Stream $candidateText '_POSITION')
    $normal = @(Read-Stream $baselineText '_NORMAL')
    if ($oldPosition.Count -ne $newPosition.Count -or $oldPosition.Count -ne $normal.Count) {
        $failures.Add("$relative vertex count changed")
        continue
    }
    for ($i = 0; $i -lt $oldPosition.Count; $i++) {
        foreach ($axis in @('X', 'Y', 'Z')) {
            $expected = $oldPosition[$i].$axis + ($normal[$i].$axis * $Offset)
            if ([Math]::Abs($newPosition[$i].$axis - $expected) -gt 0.00002) {
                $failures.Add("$relative vertex $i axis $axis is not shifted $Offset m toward the cabin-facing normal")
            }
        }
    }
    if ((Normalize-Pim $candidateText) -cne (Normalize-Pim $baselineText)) {
        $failures.Add("$relative changed content other than positions and HUD shader")
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Package).Path)
$baselineZip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $BaselinePackage).Path)
try {
    function Read-ZipText($archive, [string]$name) {
        $entry = $archive.GetEntry($name)
        if ($null -eq $entry) { throw "Missing entry: $name" }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    function Zip-Hash($entry) {
        $sha = [Security.Cryptography.SHA256]::Create()
        $stream = $entry.Open()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') } finally { $stream.Dispose(); $sha.Dispose() }
    }

    $manifest = Read-ZipText $zip 'manifest.sii'
    if ($manifest -notmatch 'package_version:\s*"1\.4"') { $failures.Add('HUD package version is not 1.4') }

    $materials = @($zip.Entries | Where-Object { $_.FullName -match '^automat/.+\.mat$' })
    if ($materials.Count -ne 1) { $failures.Add("Expected one HUD material, found $($materials.Count)") }
    else {
        $material = Read-ZipText $zip $materials[0].FullName
        if ($material -notmatch 'effect\s*:\s*"eut2\.dif\.lum\.add\.rfx"') { $failures.Add('Compiled HUD material is not additive/transparent') }
        if ($material -match 'dif\.lum\.a\.rfx') { $failures.Add('Opaque alpha-tested HUD material remains') }
    }

    $candidateNames = @($zip.Entries | Where-Object Name | ForEach-Object FullName | Sort-Object)
    $baselineNames = @($baselineZip.Entries | Where-Object Name | ForEach-Object FullName | Sort-Object)
    $missingBaselineEntries = @($baselineNames | Where-Object { $_ -notin $candidateNames })
    if ($missingBaselineEntries.Count -gt 0) { $failures.Add("Existing package entries were removed: $($missingBaselineEntries -join ', ')") }

    $pmgs = @($zip.Entries | Where-Object { $_.FullName -match '/optical_hud(?:_large|_extra_large)?\.pmg$' })
    if ($pmgs.Count -ne 9) { $failures.Add("Expected 9 compiled PMG models, found $($pmgs.Count)") }
    foreach ($pmg in $pmgs) {
        $old = $baselineZip.GetEntry($pmg.FullName)
        if ($null -eq $old -or (Zip-Hash $pmg) -eq (Zip-Hash $old)) {
            $failures.Add("Compiled model was not moved toward cabin: $($pmg.FullName)")
        }
    }
} finally {
    $zip.Dispose()
    $baselineZip.Dispose()
}

if ($failures.Count -gt 0) {
    $failures | Select-Object -Unique | ForEach-Object { Write-Host "FAIL: $_" }
    exit 1
}

Write-Host 'PASS: HUD keeps additive transparency and all nine models are shifted 0.03 m toward the cabin-facing normal.'
