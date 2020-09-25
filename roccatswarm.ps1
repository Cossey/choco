PackageName "ROCCAT Swarm"

#Common Script Vars
$templatename = "roccatswarm"
$tempfolder = "$temp/$templatename/"
$verfile = "$templatename.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$downloadpagehtml = (Invoke-WebRequest "https://en.roccat.org/Support/Product/ROCCAT-Swarm").Content
$downloaddatahtml = [regex]::match($downloadpagehtml, "<div id=`"Downloads`">(.*?)<span>Previous versions:</span>")
$version = [regex]::match($downloaddatahtml, "class=`"Version`".*?<span>V:(.*?)</span>").Groups[1].Value

if (VersionNotValid $version $templatename) {return}

if (VersionNotNew $oldversion $version) {return}

$baseurl = [regex]::match($downloadpagehtml, "<base href=`"(.*?)`">").Groups[1].Value

$downloadurlraw = [regex]::match($downloaddatahtml, "<button name=`"download`".*?value=`"(.*?)`"").Groups[1].Value

if (DownloadNotValid $downloadurlraw $templatename) {return}

$changelog = [regex]::match($downloaddatahtml, "Changelog:</span></div>(.*?)<div class=`"Dropdown`">").Groups[1].Value

$changelog = ProcessChangelog $changelog

$downloadurl = JoinPath(@($baseurl, $downloadurlraw))

$fileinfo = HashAndSizeFromFileURL $downloadurl
$filehash = $fileinfo[0]
$filesize = $fileinfo[1]

BuildTemplate $tempfolder $templatename $filehash $downloadurl $version $changelog
if (!(PackAndClean $tempfolder)) {return}

NotePackageUpdate $version $verfile $templatename (GetFileSize $filesize)
