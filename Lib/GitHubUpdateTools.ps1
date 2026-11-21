param(
    [ValidateSet('Check','StageLocal','Apply','Repair','Revert')][string]$Operation = 'Check',
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$Repository = '',
    [string]$LocalZip = '',
    [string]$Interpreter = '',
    [int]$ControllerPid = 0,
    [int]$RendererPid = 0,
    [switch]$ResumeOutput
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
$Work = Join-Path $Root '.updates'
[IO.Directory]::CreateDirectory($Work) | Out-Null
$StatusFile = Join-Path $Work 'status.ini'

function CommitTemporaryFile([string]$Temporary, [string]$Destination) {
    $backup = $Destination + '.meso-backup-' + [Guid]::NewGuid().ToString('N')
    try {
        if ([IO.File]::Exists($Destination)) {
            [IO.File]::Replace($Temporary, $Destination, $backup)
        } else {
            [IO.File]::Move($Temporary, $Destination)
        }
    } finally {
        if ([IO.File]::Exists($backup)) {
            try { [IO.File]::Delete($backup) } catch {}
        }
    }
}
function AtomicText([string]$Path, [string]$Content) {
    $tmp = $Path + '.new-' + [Guid]::NewGuid().ToString('N')
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    try {
        [IO.File]::WriteAllText($tmp, $Content, $Utf8)
        for ($attempt = 0; $attempt -lt 15; $attempt++) {
            try {
                CommitTemporaryFile $tmp $Path
                return
            } catch {
                if ($attempt -eq 14) { throw }
                Start-Sleep -Milliseconds 90
            }
        }
    } finally {
        if ([IO.File]::Exists($tmp)) { try { [IO.File]::Delete($tmp) } catch {} }
    }
}
function WriteJson([string]$Path, $Object) {
    AtomicText $Path ($Object | ConvertTo-Json -Compress -Depth 12)
}
function ReadJson([string]$Path) {
    return [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}
function Status([string]$State, [string]$Message, [string]$Version = '') {
    $Message = $Message -replace '[\r\n=]', ' '
    $Version = $Version -replace '[\r\n=]', ''
    AtomicText $StatusFile "[Update]`r`nState=$State`r`nMessage=$Message`r`nVersion=$Version`r`n"
}
function Sha([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
function SafePath([string]$Base, [string]$Relative) {
    $rel = $Relative.Replace('/', '\')
    if ([string]::IsNullOrWhiteSpace($rel) -or $rel.Contains(':') -or $rel.StartsWith('\') -or $rel -match '(^|\\)\.{1,2}(\\|$)' -or $rel -match '[\x00-\x1f]') { throw 'Unsafe update path' }
    foreach ($part in $rel.Split('\')) {
        if (-not $part -or $part.EndsWith(' ') -or $part.EndsWith('.') -or $part -match '^(?i:con|prn|aux|nul|com[0-9]|lpt[0-9])(\.|$)') { throw 'Unsafe update filename' }
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Base $rel))
    $basePath = [IO.Path]::GetFullPath($Base).TrimEnd('\') + '\'
    if (-not $full.StartsWith($basePath, [StringComparison]::OrdinalIgnoreCase)) { throw 'Update path escapes installation' }
    $parent = [IO.Path]::GetDirectoryName($full)
    while ($parent -and $parent.Length -ge $Base.Length) {
        if ([IO.Directory]::Exists($parent)) {
            $item = Get-Item -LiteralPath $parent -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Symbolic link in update path' }
        }
        $parent = [IO.Path]::GetDirectoryName($parent)
    }
    return $full
}
function Approved([string]$Relative) {
    $rel = $Relative.Replace('\', '/')
    if ($rel -match '(?i)(^|/)(runtime|Profiles|Macros|\.updates|Releases|\.git)(/|$)' -or $rel -match '(?i)^(Meso_Chaos.ini|Slots_Options.ini|Meso_Updates.ini|Interact_Delay.ini|identity.dpapi)$') { return $false }
    if ($rel -match '^Meso_[A-Za-z0-9_]+\.(ahk|vbs|bat|png|ico)$' -or $rel -match '^(1|2)\.wav$' -or $rel -match '^ui_layer_[0-9]+\.png$' -or $rel -eq 'version.ini') { return $true }
    if ($rel -match '^Lib/[A-Za-z0-9_]+\.(ahk|ps1)$' -or $rel -match '^Ui/[A-Za-z0-9_. -]+\.(png|ico)$' -or $rel -match '^StreamerBot/[A-Za-z0-9_]+\.cs$') { return $true }
    if ($rel -match '^InteractDelay/Interact_Delay\.(ahk|png|ico)$' -or $rel -match '^Defaults/[A-Za-z0-9_]+\.ini$' -or $rel -match '^Tests/[A-Za-z0-9_]+\.(ahk|ps1)$') { return $true }
    if ($rel -eq 'CREATE_RELEASE.cmd') { return $true }
    return $false
}
function FileVersion([string]$Path) {
    if (-not [IO.File]::Exists($Path)) { throw 'Package version.ini missing' }
    $content = [IO.File]::ReadAllText($Path)
    $match = [regex]::Match($content, '(?m)^Version=(\d+\.\d+\.\d+)\s*$')
    if (-not $match.Success) { throw 'Package version must be X.Y.Z' }
    return [Version]$match.Groups[1].Value
}
function VersionText([Version]$Version) {
    return ('{0}.{1}.{2}' -f $Version.Major, $Version.Minor, $Version.Build)
}
function StagePackage([string]$Archive, [string]$ExpectedHash, [string]$Source, [string]$ReleaseVersion = '') {
    if (-not [IO.File]::Exists($Archive)) { throw 'Update ZIP not found' }
    $size = (Get-Item -LiteralPath $Archive).Length
    if ($size -le 0 -or $size -gt 157286400) { throw 'Update ZIP exceeds 150 MB limit' }
    $hash = Sha $Archive
    if ($ExpectedHash -and $hash -ne $ExpectedHash.ToLowerInvariant()) { throw 'Release checksum does not match' }
    $name = 'stage-' + [Guid]::NewGuid().ToString('N')
    $stage = Join-Path $Work $name
    [IO.Directory]::CreateDirectory($stage) | Out-Null
    $entries = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $files = @()
    $total = [int64]0
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
        try {
            foreach ($entry in $zip.Entries) {
                $relative = $entry.FullName.Replace('\', '/')
                if ($relative.EndsWith('/')) { continue }
                if (-not (Approved $relative) -or -not $entries.Add($relative)) { throw 'Duplicate or unsupported file in update ZIP' }
                if (($entry.ExternalAttributes -shr 16 -band 61440) -eq 40960) { throw 'Symbolic links are not allowed' }
                if ($entry.Length -gt 104857600) { throw 'Update file exceeds 100 MB' }
                $total += $entry.Length
                if ($entries.Count -gt 400 -or $total -gt 262144000) { throw 'Update contains too many files or expands too large' }
                $destination = SafePath $stage $relative
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
                $input = $entry.Open()
                $output = [IO.File]::Create($destination)
                try { $input.CopyTo($output) } finally { $input.Dispose(); $output.Dispose() }
                $files += [PSCustomObject]@{Path=$relative; Size=$entry.Length; Sha256=(Sha $destination)}
            }
        } finally { $zip.Dispose() }
        foreach ($required in @('Meso_Control.ahk','Meso_Stream_Output.ahk','Lib/Core.ahk','Lib/GitHubUpdateTools.ps1','version.ini')) {
            if (-not $entries.Contains($required)) { throw "Incomplete app ZIP: $required" }
        }
        $appVersion = FileVersion (Join-Path $stage 'version.ini')
        $installedVersion = FileVersion (Join-Path $Root 'version.ini')
        if ($appVersion -lt $installedVersion) { throw 'Downgrades are not supported' }
        if ($ReleaseVersion -and (VersionText $appVersion) -ne $ReleaseVersion) { throw 'Release tag and version.ini differ' }
        $manifest = @{Schema=1; Version=(VersionText $appVersion); ArchiveSha256=$hash; Stage=$name; Files=$files; Source=$Source}
        WriteJson (Join-Path $Work 'ready.json') $manifest
        return (VersionText $appVersion)
    } catch {
        if ([IO.Directory]::Exists($stage)) { [IO.Directory]::Delete($stage, $true) }
        throw
    }
}
function DownloadAsset($Asset, [string]$Path) {
    $uri = [Uri]([string]$Asset.browser_download_url)
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com') { throw 'Release asset must be hosted on GitHub HTTPS' }
    Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $Path -MaximumRedirection 5 -TimeoutSec 90 -UseBasicParsing -Headers @{'User-Agent'='Meso-Control-Updater'} | Out-Null
}
function ReplaceFile([string]$Source, [string]$Destination) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination)) | Out-Null
    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        $tmp = $Destination + '.meso-new-' + [Guid]::NewGuid().ToString('N')
        try {
            [IO.File]::Copy($Source, $tmp, $false)
            CommitTemporaryFile $tmp $Destination
            return
        } catch {
            if ($attempt -eq 24) { throw }
            Start-Sleep -Milliseconds 90
        } finally {
            if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
        }
    }
}
function Rollback {
    $path = Join-Path $Work 'transaction.json'
    if (-not [IO.File]::Exists($path)) { return }
    $transaction = ReadJson $path
    if ($transaction.State -ne 'applying') { return }
    if ($transaction.Backup -notmatch '^backup-[a-f0-9]{32}$') { throw 'Invalid rollback journal' }
    $backupRoot = Join-Path $Work $transaction.Backup
    foreach ($entry in @($transaction.Files)) {
        if (-not (Approved $entry.Path)) { throw 'Invalid rollback file' }
        $dest = SafePath $Root $entry.Path
        if ($entry.Existed) {
            $backup = SafePath $backupRoot $entry.Path
            if ((Sha $backup) -ne $entry.PreviousHash) { throw 'Rollback backup failed verification' }
            ReplaceFile $backup $dest
        } elseif ([IO.File]::Exists($dest)) { [IO.File]::Delete($dest) }
    }
    $transaction.State = 'rolled-back'
    WriteJson $path $transaction
}

function RevertPreviousTransaction {
    $journalPath = Join-Path $Work 'transaction.json'
    if (-not [IO.File]::Exists($journalPath)) { throw 'No previous update backup exists' }
    $journal = ReadJson $journalPath
    if ($journal.State -ne 'complete' -or $journal.Backup -notmatch '^backup-[a-f0-9]{32}$') { throw 'No completed update available to restore' }
    $current = VersionText (FileVersion (Join-Path $Root 'version.ini'))
    if ($journal.ToVersion -and $journal.ToVersion -ne $current) { throw 'Current version does not match the saved rollback' }
    $original = Join-Path $Work $journal.Backup
    $previous = VersionText (FileVersion (SafePath $original 'version.ini'))
    if ([Version]$previous -ge [Version]$current) { throw 'Previous version backup must be older than installed version' }
    if ($journal.FromVersion -and $previous -ne $journal.FromVersion) { throw 'Previous version metadata differs from backup' }
    $entries = @($journal.Files)
    if ($entries.Count -lt 5 -or $entries.Count -gt 400) { throw 'Invalid rollback entry count' }
    foreach ($entry in $entries) {
        if (-not (Approved $entry.Path)) { throw 'Unsafe rollback file' }
        if ($entry.Existed) {
            if ($entry.PreviousHash -notmatch '^[a-f0-9]{64}$') { throw 'Invalid rollback checksum' }
            if ((Sha (SafePath $original $entry.Path)) -ne $entry.PreviousHash) { throw 'Previous version backup failed verification' }
        }
    }
    $safetyName = 'backup-' + [Guid]::NewGuid().ToString('N')
    $safetyRoot = Join-Path $Work $safetyName
    [IO.Directory]::CreateDirectory($safetyRoot) | Out-Null
    $safetyEntries = @()
    foreach ($entry in $entries) {
        $dest = SafePath $Root $entry.Path
        $exists = [IO.File]::Exists($dest)
        if ($exists) {
            $copy = SafePath $safetyRoot $entry.Path
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($copy)) | Out-Null
            [IO.File]::Copy($dest, $copy, $false)
        }
        $safetyEntries += [PSCustomObject]@{Path=$entry.Path; Existed=$exists}
    }
    try {
        foreach ($entry in $entries) {
            $dest = SafePath $Root $entry.Path
            if ($entry.Existed) { ReplaceFile (SafePath $original $entry.Path) $dest }
            elseif ([IO.File]::Exists($dest)) { [IO.File]::Delete($dest) }
        }
        foreach ($entry in $entries) {
            if ($entry.Existed -and (Sha (SafePath $Root $entry.Path)) -ne $entry.PreviousHash) { throw 'Restored file failed verification' }
        }
        $restored = VersionText (FileVersion (Join-Path $Root 'version.ini'))
        if ($journal.FromVersion -and $restored -ne $journal.FromVersion) { throw 'Previous version failed validation' }
        $journal.State = 'reverted'
        WriteJson $journalPath $journal
        $readyFile = Join-Path $Work 'ready.json'
        if ([IO.File]::Exists($readyFile)) { [IO.File]::Delete($readyFile) }
        Status 'reverted' 'Previous version restored. Settings preserved.' $restored
    } catch {
        foreach ($entry in $safetyEntries) {
            $dest = SafePath $Root $entry.Path
            if ($entry.Existed) { ReplaceFile (SafePath $safetyRoot $entry.Path) $dest }
            elseif ([IO.File]::Exists($dest)) { [IO.File]::Delete($dest) }
        }
        throw
    }
}
function WaitProcess([int]$Id) {
    if ($Id -le 0) { return }
    $proc = Get-Process -Id $Id -ErrorAction SilentlyContinue
    if ($proc -and -not $proc.WaitForExit(30000)) { throw 'Close Meso Control before installing the update' }
}
function RestartController {
    if ($ControllerPid -gt 0 -and (Get-Process -Id $ControllerPid -ErrorAction SilentlyContinue)) {
        throw 'Previous Meso Control instance is still running'
    }
    if (-not $Interpreter -or -not [IO.File]::Exists($Interpreter)) {
        throw 'AutoHotkey interpreter not found; update installed but could not relaunch Meso Control'
    }
    $script = Join-Path $Root 'Meso_Control.ahk'
    if (-not [IO.File]::Exists($script)) { throw 'Updated Meso Control script is missing' }
    $args = '"' + $script + '"'
    if ($ResumeOutput) { $args += ' --restore-output' }
    $launched = Start-Process -FilePath $Interpreter -ArgumentList $args -WorkingDirectory $Root -PassThru -ErrorAction Stop
    Start-Sleep -Milliseconds 800
    $launched.Refresh()
    if ($launched.HasExited) { throw 'Meso Control exited during automatic relaunch; see runtime\Meso.log' }
}
$identity = [Security.Cryptography.SHA256]::Create()
try { $name = ([BitConverter]::ToString($identity.ComputeHash($Utf8.GetBytes($Root.ToLowerInvariant())))).Replace('-', '').Substring(0,24) }
finally { $identity.Dispose() }
$mutex = [Threading.Mutex]::new($false, ('Local\Meso-GitHubUpdate-' + $name))
$locked = $false
try {
    $locked = $mutex.WaitOne(0)
    if (-not $locked) { throw 'Another update operation is already running' }
    $errorLog = Join-Path $Work 'last-error.txt'
    if ([IO.File]::Exists($errorLog)) { try { [IO.File]::Delete($errorLog) } catch {} }
    $startText = if ($Operation -eq 'Check') { 'Connecting to GitHub...' } elseif ($Operation -eq 'StageLocal') { 'Validating local ZIP...' } else { 'Processing update...' }
    Status 'working' $startText
    switch ($Operation) {
        'Check' {
            if ($Repository -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$') { throw 'Set a valid public GitHub repository: owner/repo' }
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $url = 'https://api.github.com/repos/' + $Repository + '/releases/latest'
            $release = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing -TimeoutSec 30 -Headers @{'User-Agent'='Meso-Control-Updater';'Accept'='application/vnd.github+json'}
            if ($release.draft -or $release.prerelease) { throw 'Latest release is not a stable release' }
            Status 'working' 'Checking release version...'
            $tag = [string]$release.tag_name
            $tagMatch = [regex]::Match($tag, '^v?(\d+\.\d+\.\d+)$')
            if (-not $tagMatch.Success) { throw 'Release tag must be vX.Y.Z' }
            $latest = [Version]$tagMatch.Groups[1].Value
            $current = FileVersion (Join-Path $Root 'version.ini')
            if ($latest -lt $current) { Status 'current' 'No newer release on GitHub' (VersionText $current); break }
            if ($latest -eq $current) { Status 'current' 'App is up to date' (VersionText $current); break }
            $asset = @($release.assets | Where-Object { $_.name -match '^Meso_Control_[0-9_]+(?:_COMPLETE)?\.zip$' -or $_.name -eq 'Meso_Control_COMPLETE.zip' } | Select-Object -First 1)
            if ($asset.Count -ne 1) { throw 'Release ZIP not found in the GitHub release' }
            if ([int64]$asset[0].size -le 0 -or [int64]$asset[0].size -gt 157286400) { throw 'Release ZIP exceeds size limit' }
            $expected = ''
            if ([string]$asset[0].digest -match '^sha256:([a-fA-F0-9]{64})$') { $expected = $Matches[1].ToLowerInvariant() }
            $checksumAsset = @($release.assets | Where-Object { $_.name -eq ([string]$asset[0].name + '.sha256') } | Select-Object -First 1)
            if ($checksumAsset.Count -eq 1) {
                $checksumFile = Join-Path $Work 'online.sha256'
                Status 'working' 'Verifying release checksum...'
                DownloadAsset $checksumAsset[0] $checksumFile
                $checksumText = [IO.File]::ReadAllText($checksumFile)
                $hashMatch = [regex]::Match($checksumText, '^\s*([a-fA-F0-9]{64})(\s|$)')
                if (-not $hashMatch.Success) { throw 'Release checksum file is invalid' }
                $listedHash = $hashMatch.Groups[1].Value.ToLowerInvariant()
                if ($expected -and $expected -ne $listedHash) { throw 'GitHub digest differs from checksum file' }
                $expected = $listedHash
            }
            if (-not $expected) { throw 'Release needs its .zip.sha256 checksum file (CREATE_RELEASE.cmd creates it)' }
            $download = Join-Path $Work 'online-download.zip'
            Status 'working' 'Downloading update...'
            DownloadAsset $asset[0] $download
            Status 'working' 'Validating downloaded files...'
            $ver = StagePackage $download $expected ('GitHub ' + $Repository) (VersionText $latest)
            Status 'ready' 'Update checked, downloaded, and validated. Click Install.' $ver
        }
        'StageLocal' {
            if (-not $LocalZip -or -not [IO.File]::Exists($LocalZip)) { throw 'Select a valid local ZIP' }
            Status 'working' 'Validating local ZIP...'
            $ver = StagePackage $LocalZip '' 'Local ZIP'
            Status 'ready' 'Local ZIP validated. Click Install to apply.' $ver
        }
        'Apply' {
            WaitProcess $ControllerPid
            WaitProcess $RendererPid
            Rollback
            $ready = ReadJson (Join-Path $Work 'ready.json')
            if ($ready.Schema -ne 1 -or $ready.Stage -notmatch '^stage-[a-f0-9]{32}$' -or $ready.ArchiveSha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid staged release' }
            $stage = Join-Path $Work $ready.Stage
            if ([Version]$ready.Version -lt (FileVersion (Join-Path $Root 'version.ini'))) { throw 'This release is older than the installed version' }
            $files = @($ready.Files)
            if ($files.Count -lt 5 -or $files.Count -gt 400) { throw 'Invalid file list' }
            if ((VersionText (FileVersion (Join-Path $stage 'version.ini'))) -ne $ready.Version) { throw 'Staged version changed' }
            foreach ($entry in $files) {
                if (-not (Approved $entry.Path) -or $entry.Sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Unsafe staged file' }
                if ((Sha (SafePath $stage $entry.Path)) -ne $entry.Sha256) { throw 'Staged file checksum mismatch' }
            }
            $backupName = 'backup-' + [Guid]::NewGuid().ToString('N')
            $backupRoot = Join-Path $Work $backupName
            [IO.Directory]::CreateDirectory($backupRoot) | Out-Null
            $receipt = @()
            foreach ($entry in $files) {
                $dest = SafePath $Root $entry.Path
                $exists = [IO.File]::Exists($dest)
                $oldHash = ''
                if ($exists) {
                    $bak = SafePath $backupRoot $entry.Path
                    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bak)) | Out-Null
                    [IO.File]::Copy($dest, $bak, $false)
                    $oldHash = Sha $bak
                }
                $receipt += [PSCustomObject]@{Path=$entry.Path; Existed=$exists; PreviousHash=$oldHash}
            }
            $journalPath = Join-Path $Work 'transaction.json'
            $fromVersion = VersionText (FileVersion (Join-Path $Root 'version.ini'))
            $journal = @{Schema=1; State='applying'; Backup=$backupName; Files=$receipt; FromVersion=$fromVersion; ToVersion=$ready.Version}
            WriteJson $journalPath $journal
            try {
                foreach ($entry in $files) { ReplaceFile (SafePath $stage $entry.Path) (SafePath $Root $entry.Path) }
                foreach ($entry in $files) {
                    if ((Sha (SafePath $Root $entry.Path)) -ne $entry.Sha256) { throw 'Installed file failed checksum verification' }
                }
                $journal.State = 'complete'
                WriteJson $journalPath $journal
                [IO.File]::Delete((Join-Path $Work 'ready.json'))
                Status 'installed' 'Update installed. Profiles, macros, and settings preserved.' $ready.Version
            } catch { Rollback; throw }
            RestartController
        }
        'Revert' {
            WaitProcess $ControllerPid
            WaitProcess $RendererPid
            RevertPreviousTransaction
            RestartController
        }
        'Repair' {
            WaitProcess $ControllerPid
            WaitProcess $RendererPid
            Rollback
            Status 'repaired' 'Recovered from the interrupted update'
            RestartController
        }
    }
} catch {
    $failure = $_.Exception.Message
    try { [IO.File]::WriteAllText((Join-Path $Work 'last-error.txt'), $_.Exception.ToString(), $Utf8) } catch {}
    try { Status 'error' $failure } catch {}
    if ($Operation -eq 'Apply' -or $Operation -eq 'Repair' -or $Operation -eq 'Revert') { try { RestartController } catch {} }
    exit 1
} finally {
    if ($locked) { try { $mutex.ReleaseMutex() } catch {} }
    try { $mutex.Dispose() } catch {}
}
