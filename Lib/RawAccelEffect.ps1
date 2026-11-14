[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Folder,
    [Parameter(Mandatory)][string]$StatusPath,
    [Parameter(Mandatory)][int]$ControllerPid,
    [Parameter(Mandatory)][long]$Target,
    [Parameter(Mandatory)][ValidateRange(100,300000)][int]$DurationMs,
    [Parameter(Mandatory)][string]$Multiplier
)

$ErrorActionPreference = 'Stop'
$mutex = $null
$locked = $false
$baseline = $null
$applied = $false
$failure = ''
$receipt = "$StatusPath.restore.json"
$utf8 = [Text.UTF8Encoding]::new($false)

function Write-Status([string]$Text) {
    [IO.File]::WriteAllText("$StatusPath.tmp", $Text, $utf8)
    if ([IO.File]::Exists($StatusPath)) {
        [IO.File]::Replace("$StatusPath.tmp", $StatusPath, $null)
    } else {
        [IO.File]::Move("$StatusPath.tmp", $StatusPath)
    }
}

function Write-InputLog([string]$Message) {
    try {
        [IO.File]::AppendAllText((Join-Path (Split-Path $StatusPath) 'Meso.log'),
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Raw Accel: $Message`r`n", $utf8)
    } catch {}
}

function Should-End {
    return (Test-Path -LiteralPath "$StatusPath.cancel") -or $controller.HasExited -or
        [Meso.RawAccelWindow]::GetForegroundWindow().ToInt64() -ne $Target
}

try {
    # Only load the exact x64 DLLs from the official Raw Accel 1.7.1 package.
    $expected = @{
        'wrapper.dll' = 'e17d540fb0bb5e47ba7c8e01aff39f1570bfb7ef673a1ddc0bccd2a26f9efb78'
        'Newtonsoft.Json.dll' = 'b624949df8b0e3a6153fdfb730a7c6f4990b6592ee0d922e1788433d276610f3'
    }
    foreach ($name in $expected.Keys) {
        $path = Join-Path $Folder $name
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected[$name]) {
            throw 'Link the official x64 Raw Accel 1.7.1 folder'
        }
    }
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $Folder 'Newtonsoft.Json.dll'))
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $Folder 'wrapper.dll'))
    try {
        $version = [VersionHelper]::ValidOrThrow()
    } catch {
        throw 'Install Raw Accel 1.7.x and restart Windows'
    }
    if ($version.Major -ne 1 -or $version.Minor -ne 7) {
        throw 'This effect requires the Raw Accel 1.7.x driver'
    }
    $factor = [double]0
    if (![double]::TryParse($Multiplier, [Globalization.NumberStyles]::AllowDecimalPoint,
        [Globalization.CultureInfo]::InvariantCulture, [ref]$factor) -or $factor -lt 0.1 -or $factor -gt 5.0) {
        throw 'Sensitivity multiplier is outside 0.1x to 5.0x'
    }
    $controller = [Diagnostics.Process]::GetProcessById($ControllerPid)
    Add-Type -Namespace Meso -Name RawAccelWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr GetForegroundWindow();
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern ulong GetTickCount64();
'@
    $mutex = [Threading.Mutex]::new($false, 'Local\MesoControlRawAccel')
    try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (!$locked) { throw 'Raw Accel is already applying a punishment' }
    if (!(Should-End)) {
        $baseline = [DriverConfig]::GetActive()
        $result = [DriverConfig]::Convert($baseline.ToJSON())
        if ($null -eq $result.Item1) { throw 'The active Raw Accel profile could not be copied' }
        $adjusted = $result.Item1
        for ($i = 0; $i -lt $adjusted.profiles.Count; $i++) {
            $profile = $adjusted.profiles[$i]
            $profile.outputDPI *= $factor
            $adjusted.SetProfileAt($i, $profile)
        }

        if (!(Should-End)) {
            # The worker owns the restoration even after the controller exits.
            [IO.File]::WriteAllText($receipt, $baseline.ToJSON(), $utf8)
            $applied = $true
            $adjusted.Activate()
            $start = [Meso.RawAccelWindow]::GetTickCount64()
            $until = $start + $DurationMs
            if (!(Should-End)) {
                Write-Status "ready|$start|$until"
                Write-InputLog "Applied physical mouse multiplier $factor"
                while ([Meso.RawAccelWindow]::GetTickCount64() -lt $until -and !(Should-End)) {
                    Start-Sleep -Milliseconds 35
                }
            }
        }
    }
} catch {
    $failure = $_.Exception.GetBaseException().Message -replace '[\r\n|]', ' '
} finally {
    if ($applied) {
        $restored = $false
        for ($attempt = 0; $attempt -lt 3 -and !$restored; $attempt++) {
            try {
                $baseline.Activate()
                $restored = $true
                Write-InputLog 'Restored the active mouse profile'
            } catch {
                Start-Sleep -Milliseconds 300
            }
        }
        if ($restored) {
            Remove-Item -LiteralPath $receipt -ErrorAction SilentlyContinue
        } else {
            $failure = 'Raw Accel could not restore the mouse profile. Reapply your profile in Raw Accel'
        }
    }
    if ($failure) {
        Write-InputLog $failure
        try { Write-Status "error|$failure" } catch {}
    } else {
        try { Write-Status 'restored' } catch {}
    }
    Remove-Item -LiteralPath "$StatusPath.cancel" -ErrorAction SilentlyContinue
    if ($locked) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
if ($failure) { exit 1 }
