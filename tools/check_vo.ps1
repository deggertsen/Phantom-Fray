# Checks Chen's voice files against chen_lines.json by transcribing each one with ElevenLabs
# speech-to-text and comparing the words. Flags clips that dropped, added or garbled words,
# or spoke a delivery tag aloud. -Only <event> checks one moment.
# Uses the same API key as generate_elevenlabs_vo.ps1.
param([string]$Only, [double]$Threshold = 0.8)
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $projectRoot 'Assets\Audio\VO\chen'
$script = Get-Content (Join-Path $folder 'chen_lines.json') -Raw | ConvertFrom-Json
$key = $env:ELEVENLABS_API_KEY
$keyFile = Join-Path $env:APPDATA 'PhantomFray\elevenlabs_key.txt'
if (-not $key -and (Test-Path $keyFile)) { $key = (Get-Content $keyFile -Raw).Trim() }
if (-not $key) { throw "No ElevenLabs API key. Set ELEVENLABS_API_KEY or put the key in $keyFile." }
Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Add('xi-api-key', $key)

$numbers = @('zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve')

# Speech-to-text writes "three o'clock" as "3:00" and "failsafe" as "fail-safe"; read both the same.
function Words([string]$text) {
    $text = [regex]::Replace($text.ToLowerInvariant(), '\b(\d{1,2}):00\b', { param($m) $numbers[[int]$m.Groups[1].Value] + " o'clock" })
    $text = $text -replace '-', '' -replace "'", '' -replace '[^a-z0-9 ]', ' '
    return @($text -split '\s+' | Where-Object { $_ })
}

# Word-level similarity: 1 minus edit distance over the longer length.
function Similarity([string[]]$a, [string[]]$b) {
    $n = $a.Count; $m = $b.Count
    if ($n -eq 0 -and $m -eq 0) { return 1.0 }
    $w = $m + 1
    $d = New-Object 'int[]' (($n + 1) * $w)
    for ($i = 0; $i -le $n; $i++) { $d[$i * $w] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[$j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $cost = 1
            if ($a[$i - 1] -eq $b[$j - 1]) { $cost = 0 }
            $up = $d[($i - 1) * $w + $j] + 1
            $left = $d[$i * $w + $j - 1] + 1
            $diagonal = $d[($i - 1) * $w + $j - 1] + $cost
            $d[$i * $w + $j] = [Math]::Min([Math]::Min($up, $left), $diagonal)
        }
    }
    return 1.0 - $d[$n * $w + $m] / [Math]::Max($n, $m)
}

$flagged = 0
$checked = 0
foreach ($event in $script.events.PSObject.Properties) {
    if ($Only -and $event.Name -ne $Only) { continue }
    $number = 0
    foreach ($line in $event.Value.lines) {
        $number++
        $file = Join-Path $folder ("{0}_{1}.ogg" -f $event.Name, $number)
        if (-not (Test-Path $file)) { Write-Host "MISSING  $file"; $flagged++; continue }
        $form = New-Object System.Net.Http.MultipartFormDataContent
        $form.Add((New-Object System.Net.Http.StringContent 'scribe_v1'), 'model_id')
        $bytes = New-Object System.Net.Http.ByteArrayContent (, [System.IO.File]::ReadAllBytes($file))
        $form.Add($bytes, 'file', [System.IO.Path]::GetFileName($file))
        $response = $client.PostAsync('https://api.elevenlabs.io/v1/speech-to-text', $form).Result
        $heard = ($response.Content.ReadAsStringAsync().Result | ConvertFrom-Json).text
        $score = Similarity (Words $line) (Words $heard)
        $checked++
        if ($score -lt $Threshold) {
            $flagged++
            Write-Host ("CHECK    {0}_{1}  ({2:P0})" -f $event.Name, $number, $score)
            Write-Host "         wanted: $line"
            Write-Host "         heard:  $heard"
        }
    }
}
Write-Host "Checked $checked clips; $flagged need a listen."
