$ErrorActionPreference = 'Stop'

$sourcePath = 'C:\Users\LENOVO\tanker_trucksim_cosim\fluent\udf_sideways.c'
$candidatePath = Join-Path $PSScriptRoot 'udf_sideways_ascii.c'

if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw "Compatible UDF copy is missing: $candidatePath"
}

$strictGbk = [System.Text.Encoding]::GetEncoding(
    936,
    [System.Text.EncoderExceptionFallback]::new(),
    [System.Text.DecoderExceptionFallback]::new()
)
$candidateBytes = [System.IO.File]::ReadAllBytes($candidatePath)
$null = $strictGbk.GetString($candidateBytes)

function Get-CodeWithoutComments([string]$path) {
    $text = [System.IO.File]::ReadAllText($path)
    $withoutBlockComments = [regex]::Replace($text, '/\*.*?\*/', '', 'Singleline')
    $withoutComments = [regex]::Replace($withoutBlockComments, '//[^\r\n]*', '')
    return [regex]::Replace($withoutComments, '\s+', '')
}

$expectedCode = Get-CodeWithoutComments $sourcePath
$actualCode = Get-CodeWithoutComments $candidatePath
if ($actualCode -cne $expectedCode) {
    throw 'Compatible UDF copy changes executable C code; only comments/encoding may differ.'
}

Write-Output 'PASS: UDF is GBK-decodable and executable C code is unchanged.'
