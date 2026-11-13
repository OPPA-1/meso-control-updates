param([string]$Root = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not $Root) { $Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
$versionIni = [IO.File]::ReadAllText((Join-Path $Root 'version.ini'))
$found = [regex]::Match($versionIni, '(?m)^Version=(\d+\.\d+\.\d+)\s*$')
if (-not $found.Success) { throw 'Edit version.ini to Version=X.Y.Z before creating a release.' }
$version = $found.Groups[1].Value
$releaseDir = Join-Path $Root 'Releases'
[IO.Directory]::CreateDirectory($releaseDir) | Out-Null
$name = 'Meso_Control_' + $version.Replace('.', '_') + '_COMPLETE.zip'
$archiveFile = Join-Path $releaseDir $name
$checksumFile = $archiveFile + '.sha256'
if ([IO.File]::Exists($archiveFile)) { throw 'This version already has a release ZIP. Increase version.ini to publish a new version.' }
function Allowed([string]$Path) {
    $r = $Path.Replace('\','/')
    if ($r -match '(?i)(^|/)(runtime|Profiles|Macros|\.updates|Releases|\.git)(/|$)' -or $r -match '(?i)^(Meso_Chaos.ini|Slots_Options.ini|Meso_Updates.ini|Interact_Delay.ini|identity.dpapi)$') { return $false }
    if ($r -match '^Meso_[A-Za-z0-9_]+\.(ahk|vbs|bat|png|ico)$' -or $r -match '^(1|2)\.wav$' -or $r -match '^ui_layer_[0-9]+\.png$' -or $r -eq 'version.ini') { return $true }
    if ($r -match '^Lib/[A-Za-z0-9_]+\.(ahk|ps1)$' -or $r -match '^Ui/[A-Za-z0-9_. -]+\.(png|ico)$' -or $r -match '^StreamerBot/[A-Za-z0-9_]+\.cs$') { return $true }
    if ($r -match '^InteractDelay/Interact_Delay\.(ahk|png|ico)$' -or $r -match '^Defaults/[A-Za-z0-9_]+\.ini$' -or $r -match '^Tests/[A-Za-z0-9_]+\.(ahk|ps1)$') { return $true }
    if ($r -eq 'CREATE_RELEASE.cmd') { return $true }
    return $false
}
$files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object { Allowed $_.FullName.Substring($Root.Length + 1) } | Sort-Object FullName)
if ($files.Count -lt 25 -or $files.Count -gt 400) { throw 'Unexpected file count. Check the app folder.' }
$archive = [IO.Compression.ZipFile]::Open($archiveFile, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Root.Length + 1).Replace('\','/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relative, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }
$hash = (Get-FileHash -LiteralPath $archiveFile -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($checksumFile, ($hash + '  ' + $name + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ''
Write-Host ('Created ' + $archiveFile)
Write-Host ('Created ' + $checksumFile)
Write-Host ('Files: ' + $files.Count)
Write-Host ('Upload both files to the public GitHub release tagged ' + $version)
Write-Host 'Meso Control clients can then click Settings > Updates > Check online.'
