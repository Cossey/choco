$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$target = Join-Path $toolsDir "bin\siril.exe"
Install-ChocolateyShortcut -shortcutFilePath "$([Environment]::GetFolderPath('CommonStartMenu'))\Programs\SIRIL.lnk" -targetPath "$target" -description "Astronomical image processing."