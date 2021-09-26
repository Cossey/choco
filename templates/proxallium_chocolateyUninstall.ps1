$ErrorActionPreference = 'Stop'

$installDir = Join-Path $([Environment]::GetFolderPath('ApplicationData')) $packageName

Remove-Item $installDir -Recurse
Remove-Item "$([Environment]::GetFolderPath('Programs'))\ProxAllium.lnk"