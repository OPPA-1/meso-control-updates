param([string]$Root = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$checks = 0
function Check($Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
    $script:checks++
}
function Embedded([string]$Name) {
    $source = [IO.File]::ReadAllText((Join-Path $Root "Lib/$Name.ahk"))
    $chunks = [regex]::Matches($source, '(?m)^\s*data \.= "([A-Za-z0-9+/=]+)"\r?$')
    return [Convert]::FromBase64String(($chunks | ForEach-Object { $_.Groups[1].Value }) -join '')
}
function Check-Wave([byte[]]$Bytes, [double]$Seconds, [string]$Name) {
    Check ([Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -eq 'RIFF') "$Name WAV header"
    $offset = 12; $samples = $null; $rate = 0
    while ($offset + 8 -le $Bytes.Length) {
        $tag = [Text.Encoding]::ASCII.GetString($Bytes, $offset, 4)
        $size = [BitConverter]::ToInt32($Bytes, $offset + 4)
        Check ($size -ge 0 -and $offset + 8 + $size -le $Bytes.Length) "$Name valid WAV chunk"
        if ($tag -eq 'fmt ') {
            Check ([BitConverter]::ToInt16($Bytes, $offset + 8) -eq 1) "$Name PCM format"
            Check ([BitConverter]::ToInt16($Bytes, $offset + 10) -eq 1) "$Name mono output"
            Check ([BitConverter]::ToInt16($Bytes, $offset + 22) -eq 16) "$Name 16 bit output"
            $rate = [BitConverter]::ToInt32($Bytes, $offset + 12)
        }
        if ($tag -eq 'data') { $samples = @{Offset = $offset + 8; Length = $size} }
        $offset += 8 + $size + ($size % 2)
    }
    Check ($null -ne $samples -and $rate -eq 22050) "$Name usable audio data"
    Check ([Math]::Abs($samples.Length / 2.0 / $rate - $Seconds) -lt 0.002) "$Name ends with its visual"
    $sum = 0.0; $peak = 0.0
    for ($i = $samples.Offset; $i -lt $samples.Offset + $samples.Length; $i += 2) {
        $sample = [BitConverter]::ToInt16($Bytes, $i) / 32768.0
        $sum += $sample * $sample
        $peak = [Math]::Max($peak, [Math]::Abs($sample))
    }
    $db = 20 * [Math]::Log10([Math]::Sqrt($sum / ($samples.Length / 2)))
    Check ($db -ge -4 -and $db -le -2 -and $peak -lt 0.991) "$Name loud normalized audio without clipping"
}
foreach ($spec in @(@{N=1;W=384;H=288;Frames=14;Seconds=0.840})) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Root "Ui/scare$($spec.N).png"))
    try {
        Check ($image.Width -eq $spec.W * 4 -and $image.Height -eq [Math]::Ceiling($spec.Frames / 4.0) * $spec.H) 'Scare sprite sheet dimensions'
        for ($frame = 0; $frame -lt $spec.Frames; $frame++) {
            $x = ($frame % 4) * $spec.W; $y = [Math]::Floor($frame / 4) * $spec.H
            $transparent = 0; $visible = 0
            for ($py = 0; $py -lt $spec.H; $py += 4) {
                for ($px = 0; $px -lt $spec.W; $px += 4) {
                    $alpha = $image.GetPixel($x + $px, $y + $py).A
                    if ($alpha -eq 0) { $transparent++ } else { $visible++ }
                }
            }
            Check ($transparent -gt 0 -and $visible -gt 0) 'Each scare frame has a visible subject and transparent background'
        }
    } finally { $image.Dispose() }
    Check-Wave (Embedded "ScareAudio$($spec.N)") $spec.Seconds "Jumpscare $($spec.N)"
}
$omni = [Drawing.Bitmap]::FromFile((Join-Path $Root 'Ui/omni.png'))
try {
    Check ($omni.Width -eq 1227 -and $omni.Height -eq 1281) 'Omni dimensions'
    Check ($omni.GetPixel(0,0).A -eq 0) 'Omni white background is transparent'
} finally { $omni.Dispose() }
Check (!(Test-Path (Join-Path $Root 'Ui/scare2.png'))) 'FNAF 2 visual is removed'
Check-Wave (Embedded 'ScareAudio2') 0.303 'Omni linked 4124 audio'
Check-Wave (Embedded 'SonionScream') 3.2 'Sonion answer scare'
Check-Wave ([IO.File]::ReadAllBytes((Join-Path $Root '1.wav'))) 15 'Tung'
Check-Wave ([IO.File]::ReadAllBytes((Join-Path $Root '2.wav'))) 7 'Tung figure'
Write-Output "PASS $checks media checks"
