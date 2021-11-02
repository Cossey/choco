$ErrorActionPreference = 'Stop'
$ProgramsMenu = $([Environment]::GetFolderPath('CommonPrograms'))

$installDir = Join-Path (Get-ToolsLocation) $packageName

Remove-Item $installDir -Recurse
Remove-Item "$ProgramsMenu\ProxAllium.lnk"