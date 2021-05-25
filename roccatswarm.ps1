PackageName "ROCCAT Swarm"

#Common Script Vars
$templatename = "roccatswarm"
$tempfolder = "$temp/$templatename/"
$verfile = "$templatename.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$downloadapi = (Invoke-WebRequest "https://api.roccat-neon.com/device/Support/Downloads/en/202/v2").Content
$apijson = ConvertFrom-Json $downloadapi

$item = $apijson.download;

if (ItemNotDefined $item $templatename "item") {return}

$version = $item.version
$release = "Released $($item.release)"

if (VersionNotValid $version $templatename) {return}

if (VersionNotNew $oldversion $version) {return}

$changelogjson = $item.changelog.'ROCCAT® Swarm'[0].changelog;

foreach ($log in $changelogjson) {
    $changelogdata = "$changelogdata`n* $log"
}

$changelog = @"
$release
$changelogdata
"@

$downloadurl = $item.url

$fileinfo = HashAndSizeFromFileURL $downloadurl
$filehash = $fileinfo[0]
$filesize = $fileinfo[1]

BuildTemplate $tempfolder $templatename $filehash $downloadurl $version $changelog
if (!(PackAndClean $tempfolder)) {return}

NotePackageUpdate $version $verfile $templatename (GetFileSize $filesize)
