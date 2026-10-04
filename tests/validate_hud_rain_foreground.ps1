param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Baseline
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$failures = [Collections.Generic.List[string]]::new()

function Open-Package([string]$packagePath) {
    return [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $packagePath).Path)
}

function Read-EntryText($zip, [string]$name) {
    $entry = $zip.GetEntry($name)
    if ($null -eq $entry) { throw "Missing package entry: $name" }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Entry-Hash($entry) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = $entry.Open()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') } finally { $stream.Dispose(); $sha.Dispose() }
}

$candidate = Open-Package $Path
$baselineZip = Open-Package $Baseline
try {
    $manifest = Read-EntryText $candidate "manifest.sii"
    if ($manifest -notmatch 'package_version:\s*"1\.2"') { $failures.Add("HUD package version is not 1.2") }

    $materialEntries = @($candidate.Entries | Where-Object { $_.FullName -match '^automat/.+\.mat$' })
    if ($materialEntries.Count -ne 1) {
        $failures.Add("Expected exactly one compiled HUD material, found $($materialEntries.Count)")
    } else {
        $material = Read-EntryText $candidate $materialEntries[0].FullName
        if ($material -notmatch 'effect\s*:\s*"eut2\.dif\.lum\.a\.rfx"') {
            $failures.Add("HUD does not use the alpha-tested luminance shader needed to write depth ahead of windshield rain")
        }
        if ($material -match 'dif\.lum\.add') {
            $failures.Add("Old additive shader remains and can be distorted by windshield rain")
        }
    }

    $candidateNames = @($candidate.Entries | Where-Object Name | ForEach-Object FullName | Sort-Object)
    $baselineNames = @($baselineZip.Entries | Where-Object Name | ForEach-Object FullName | Sort-Object)
    if (Compare-Object $candidateNames $baselineNames) {
        $failures.Add("Rain-layer fix changed the package entry set")
    }

    $allowedChanges = @('manifest.sii', 'description.txt') + @($materialEntries | ForEach-Object FullName)
    foreach ($entry in $candidate.Entries | Where-Object Name) {
        if ($entry.FullName -in $allowedChanges) { continue }
        $old = $baselineZip.GetEntry($entry.FullName)
        $same = $false
        if ($null -ne $old) {
            if ($entry.FullName -match '\.sii$' -or $entry.FullName -match '^material/ui/.+\.(mat|tobj)$') {
                $newText = (Read-EntryText $candidate $entry.FullName).Replace("`r`n", "`n")
                $oldText = (Read-EntryText $baselineZip $entry.FullName).Replace("`r`n", "`n")
                $same = $newText -ceq $oldText
            } else {
                $same = (Entry-Hash $entry) -eq (Entry-Hash $old)
            }
        }
        if (-not $same) {
            $failures.Add("Unexpected view/geometry/UI change: $($entry.FullName)")
        }
    }
} finally {
    $candidate.Dispose()
    $baselineZip.Dispose()
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" }
    exit 1
}

Write-Host "PASS: HUD uses alpha-tested depth rendering ahead of rain; geometry, UI, and package scope are unchanged."
