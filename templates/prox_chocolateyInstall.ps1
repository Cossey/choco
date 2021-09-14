$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$target = Join-Path $toolsDir "ProxAllium.exe"

Install-ChocolateyShortcut -shortcutFilePath "$([Environment]::GetFolderPath('CommonStartMenu'))\Programs\ProxAllium.lnk" -targetPath "$target" -description "A GUI frontend for Tor."