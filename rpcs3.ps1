Write-Host "[RPCS3 Package Updater]" -ForegroundColor Yellow

#Common Script Vars
$templatename = "rpcs3"
$tempfolder = "$temp/rpcs3/"
$verfile = "rpcs3.ver"
$oldversion = GetLastVersion $verfile

if ($oldversion -eq "~") {
    Write-Host "Skip Updating Package"
    break
}

$dljson = (Invoke-WebRequest "https://api.github.com/repos/RPCS3/rpcs3-binaries-win/releases/latest").Content
$dlinfo = ConvertFrom-Json $dljson
$version = $dlinfo.name.Replace('-', '.')

if ($oldversion -ne $version) {
    $files = $dlinfo.assets
    $dlfile = $null
    $shafile = $null
    $sha256 = $null
    $filesize = $null

    foreach ($file in $files) {
        if ($file.browser_download_url.EndsWith('7z')) {
            $dlfile = $file.browser_download_url
            $filesize = $file.size
        }
    
        if ($file.browser_download_url.EndsWith('sha256')) {
            $shafile = $file.browser_download_url
        }
    }

    if ($shafile) {
        [string]$sha256 = Invoke-WebRequest "$shafile"
        $sha256 = $sha256.Trim()
    }

    BuildTemplate $tempfolder $templatename $sha256 $dlfile $version ""
    PackAndClean $tempfolder
    NotePackageUpdate $version $verfile $templatename (GetFileSize $filesize)
} else {
    Write-Host "No New Version"
}