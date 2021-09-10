PackageName "RPCS3"

#Common Script Vars
$templatename = "rpcs3"
$tempfolder = Join-Path $temp $templatename
$verfile = "$templatename.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$dljson = (Invoke-WebRequest "https://api.github.com/repos/RPCS3/rpcs3-binaries-win/releases/latest").Content
$dlinfo = ConvertFrom-Json $dljson
$version = $dlinfo.name

$nugetversion = ConvertDashVersion $version 'alpha'

if (VersionNotValid $nugetversion $templatename) {return}

if (VersionNotNew $oldversion $version) {return}

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

if (!(BuildTemplate $templatename $sha256 $dlfile $nugetversion "")) {return}
if (!(PackAndClean)) {return}
NotePackageUpdate $version $verfile $templatename (GetFileSize $filesize)
