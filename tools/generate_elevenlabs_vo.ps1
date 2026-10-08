# Voices Chen's lines with ElevenLabs, from Assets/Audio/VO/chen/chen_lines.json.
#
#   Find voices:   -FindVoices "calm authoritative female"
#                  Lists Voice Library matches with a preview link and an id to audition.
#   Audition:      -Audition <id>,<id>,...
#                  Voices a handful of real Chen lines per voice into reports/vo-audition/.
#                  Library ids look like <owner>/<voice>; they are added to your account first.
#   Generate:      -VoiceId <voice_id>
#                  Voices every line that is new, changed, or still a placeholder. Re-run it
#                  after editing the JSON and only the changed lines are regenerated.
#                  -Only <event> limits it to one moment; -Force redoes everything.
#
# The API key is read from the ELEVENLABS_API_KEY environment variable, or else from
# %APPDATA%\PhantomFray\elevenlabs_key.txt. It is never written into the project.
param(
    [string]$VoiceId,
    [string]$FindVoices,
    [string[]]$Audition,
    [string]$Model = 'eleven_v3',
    [string]$Only,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $projectRoot 'Assets\Audio\VO\chen'
$manifestPath = Join-Path $folder 'elevenlabs_manifest.json'
$script = Get-Content (Join-Path $folder 'chen_lines.json') -Raw | ConvertFrom-Json
$api = 'https://api.elevenlabs.io/v1'

$key = $env:ELEVENLABS_API_KEY
$keyFile = Join-Path $env:APPDATA 'PhantomFray\elevenlabs_key.txt'
if (-not $key -and (Test-Path $keyFile)) { $key = (Get-Content $keyFile -Raw).Trim() }
if (-not $key) { throw "No ElevenLabs API key. Set ELEVENLABS_API_KEY or put the key in $keyFile." }
$headers = @{ 'xi-api-key' = $key }

# Trim dead air and match the game's other voice clips. The radio sound is on the Voice bus.
$trim = 'silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,loudnorm=I=-18:TP=-2,aformat=sample_rates=22050:channel_layouts=mono'

function Speak([string]$voice, [string]$text, [string]$tag, [string]$target) {
    $spoken = if ($Model -eq 'eleven_v3' -and $tag) { "$tag $text" } else { $text }
    $settings = @{ stability = 0.5; similarity_boost = 0.8 }
    if ($Model -ne 'eleven_v3') { $settings.style = 0.25; $settings.speed = 1.05 }
    $body = @{ text = $spoken; model_id = $Model; voice_settings = $settings } | ConvertTo-Json -Depth 4
    $mp3 = [System.IO.Path]::ChangeExtension($target, '.download.mp3')
    Invoke-WebRequest -Method Post -Uri "$api/text-to-speech/$voice`?output_format=mp3_44100_128" `
        -Headers $headers -ContentType 'application/json; charset=utf-8' `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -OutFile $mp3 -UseBasicParsing | Out-Null
    & ffmpeg -hide_banner -loglevel error -y -i $mp3 -af $trim -c:a libvorbis -q:a 5 $target
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed on $target" }
    Remove-Item $mp3
}

# Library voices have to be added to the account before they can speak.
function Resolve-Voice([string]$id) {
    if ($id -notmatch '/') { return $id }
    $owner, $voice = $id.Split('/')
    $added = Invoke-RestMethod -Method Post -Uri "$api/voices/add/$owner/$voice" -Headers $headers `
        -ContentType 'application/json' -Body (@{ new_name = "Chen candidate $voice" } | ConvertTo-Json)
    return $added.voice_id
}

if ($FindVoices) {
    $query = [uri]::EscapeDataString($FindVoices)
    $found = Invoke-RestMethod -Uri "$api/shared-voices?page_size=25&gender=female&search=$query&sort=usage_character_count_1y" -Headers $headers
    foreach ($v in $found.voices) {
        Write-Host ("{0}  ({1}, {2}, {3})" -f $v.name, $v.age, $v.accent, $v.descriptive)
        Write-Host ("    audition id: {0}/{1}" -f $v.public_owner_id, $v.voice_id)
        Write-Host ("    preview:     {0}" -f $v.preview_url)
        if ($v.description) { Write-Host ("    {0}" -f ($v.description -replace '\s+', ' ')) }
    }
    return
}

if ($Audition) {
    $out = Join-Path $projectRoot 'reports\vo-audition'
    New-Item $out -ItemType Directory -Force | Out-Null
    $samples = @('mission_start', 'rift_oclock_6', 'life_critical', 'rift_sealed', 'victory')
    foreach ($candidate in $Audition) {
        $voice = Resolve-Voice $candidate
        $clips = @()
        foreach ($event in $samples) {
            $info = $script.events.$event
            $clip = Join-Path $out ("{0}_{1}.ogg" -f $voice, $event)
            Speak $voice $info.lines[0] $info.tag $clip
            $clips += $clip
        }
        # One file per voice, the lines back to back with a beat between them.
        $list = Join-Path $out "$voice.txt"
        Set-Content $list ($clips | ForEach-Object { "file '$($_ -replace '\\', '/')'" })
        $reel = Join-Path $out "$voice.ogg"
        & ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $list -af 'apad=pad_dur=0.6' -c:a libvorbis -q:a 5 $reel
        Write-Host "Audition reel: $reel"
    }
    return
}

if (-not $VoiceId) { throw 'Pass -VoiceId to generate, -Audition to compare voices, or -FindVoices to search.' }
$voice = Resolve-Voice $VoiceId
$manifest = @{}
if (Test-Path $manifestPath) {
    (Get-Content $manifestPath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $manifest[$_.Name] = $_.Value }
}
$made = 0
foreach ($event in $script.events.PSObject.Properties) {
    if ($Only -and $event.Name -ne $Only) { continue }
    $number = 0
    foreach ($line in $event.Value.lines) {
        $number++
        $name = "{0}_{1}.ogg" -f $event.Name, $number
        $target = Join-Path $folder $name
        $want = "$voice|$Model|$($event.Value.tag)|$line"
        if (-not $Force -and (Test-Path $target) -and $manifest[$name] -eq $want) { continue }
        Write-Host "Voicing $name : $line"
        Speak $voice $line $event.Value.tag $target
        $manifest[$name] = $want
        $made++
        # Save as we go, so an interrupted run picks up where it stopped.
        $manifest | ConvertTo-Json | Set-Content $manifestPath -Encoding utf8
    }
}
Write-Host "Voiced $made lines with $voice ($Model)."
