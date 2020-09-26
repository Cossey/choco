$uninstaller = ((Get-UninstallRegistryKey -SoftwareName 'Siril*').UninstallString -split '"')[1]


$packageArgs = @{
    packageName   = $env:ChocolateyPackageName
    silentArgs    = '/VERYSILENT /SUPPRESSMSGBOXES'
    validExitCodes= @(0)
    file          = $uninstaller
    fileType      = 'exe'
}

Uninstall-ChocolateyPackage @packageArgs