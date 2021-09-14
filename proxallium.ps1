PackageName "ProxAllium"

#Common Script Vars
$templatename = "prox"
$tempfolder = Join-Path $temp $templatename
$verfile = "$templatename.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$dljson = (Invoke-WebRequest "https://api.github.com/repos/DcodingTheWeb/ProxAllium/releases/latest").Content
$dlinfo = ConvertFrom-Json $dljson
$version = $dlinfo.tag_name

$version = $version -replace "v",""

if (VersionNotValid $version $templatename) {return}

if (VersionNotNew $oldversion $version) {return}

$files = $dlinfo.assets
$dlfile = $null
$fsz = $null

foreach ($file in $files) {
    if ($file.browser_download_url.EndsWith('7z')) {
        $dlfile = $file.browser_download_url
        $fsz = $file.size
    }
}

if (!(IncludeFrom7zURL $dlfile)) {return}
RemoveSubfolder

if (!(BuildTemplate $templatename "" "" $version "")) {return}
if (!(PackAndClean)) {return}
NotePackageUpdate $version $verfile $templatename $(GetFileSize $fsz)
