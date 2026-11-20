param([Parameter(Mandatory)][string]$Folder,[Parameter(Mandatory)][string]$StatusPath)
$ErrorActionPreference='Stop'
try {
    [IO.Directory]::CreateDirectory($Folder) | Out-Null
    $zip=Join-Path $Folder 'RawAccel.zip'
    Invoke-WebRequest -UseBasicParsing 'https://github.com/RawAccelOfficial/rawaccel/releases/download/v1.7.1/RawAccel_v1.7.1.zip' -OutFile $zip
    if ((Get-FileHash $zip).Hash -ne '770fe3ae0919ca3c4d412f58c985eb27f5434decad809f7e8206de4e8852eec4') {throw 'Raw Accel download checksum mismatch'}
    Expand-Archive -LiteralPath $zip -DestinationPath $Folder -Force
    Remove-Item -LiteralPath $zip
    $wrapper=Get-ChildItem -LiteralPath $Folder -Filter wrapper.dll -Recurse | Select-Object -First 1
    if (!$wrapper) {throw 'Raw Accel package did not contain wrapper.dll'}
    $installed=$wrapper.DirectoryName
    $installer=Join-Path $installed 'installer.exe'
    $process=Start-Process -FilePath $installer -WorkingDirectory $installed -Verb RunAs -Wait -PassThru
    if ($process.ExitCode -ne 0) {throw "Raw Accel installer returned $($process.ExitCode)"}
    [IO.File]::WriteAllText($StatusPath,"restart|$installed",[Text.UTF8Encoding]::new($false))
} catch {
    $message=$_.Exception.GetBaseException().Message -replace '[\r\n|]',' '
    [IO.File]::WriteAllText($StatusPath,"error|$message",[Text.UTF8Encoding]::new($false))
    exit 1
}
