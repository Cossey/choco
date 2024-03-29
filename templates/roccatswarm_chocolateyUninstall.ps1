$tools = Split-Path $MyInvocation.MyCommand.Definition
$response = Join-Path $tools 'uninstall.iss'

$uninstaller = ((Get-UninstallRegistryKey -SoftwareName 'ROCCAT Swarm').UninstallString -split '"')[1]

# This an InstallShield installer, requiring a response file (.ISS) for silent
# installation.

Uninstall-ChocolateyPackage `
    -PackageName "$env:ChocolateyPackageName" `
    -FileType 'EXE' `
    -SilentArgs "-runfromtemp -l0x0409 -removeonly -s -f1`"$response`"" `
    -File $uninstaller

Remove-Item -Path "${env:TEMP}/roccatswarm" -Recurse