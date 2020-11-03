PackageName "SIRIL"

#Common Script Vars
$templatename = "siril"
$tempfolder = Join-Path $temp $templatename
$verfile = "$templatename.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$releasespage = Invoke-WebRequest -Uri "https://free-astro.org/index.php?title=Siril:releases"

$releasespagedata = [regex]::match($releasespage.Content, "<div class=`"mw-parser-output`">(.*?)</div>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$releasedata = [regex]::match($releasespagedata, "<li>(.*?)</li>").Groups[1].Value

$version = [regex]::match($releasedata, "title=`"Siril:(.*?)`"").Groups[1].Value

if (VersionNotValid $version $templatename) {return}

if (VersionNotNew $oldversion $version) {return}

$releaseurl = [regex]::match($releasedata, "href=`"(.*?)`"").Groups[1].Value

if ($releaseurl.StartsWith("/")) {
    $releaseurl = "https://free-astro.org" + $releaseurl
}

$releasepagedata = Invoke-WebRequest -Uri "$releaseurl"
$releasedate = ([regex]::match($releasepagedata.Content, "<b>Release date: (.*?)</b>").Groups[1].Value).Trim()

Write-Host Release Date $releasedate

$changelog = [regex]::match($releasepagedata.Content, "What?'s new.*?What?'s new.*?</h2>(.*?)(<!--|</div>)", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

$changelog = (ProcessChangelog $changelog)

$description = @"
Released $releasedate
$changelog
"@


$dlurl = [regex]::match($releasepagedata.Content, "class=`"mw-headline`" id=`"Downloads`".*?<a.*? href=`"(.*?)`".*?</a>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

$dlcontent = Invoke-WebRequest -Uri "$dlurl"

foreach ($link in $dlcontent.Links) {
    if ($link.href.EndsWith(".exe")) {
        $windowsdownload = $link.href;
        break
    }
}

if (DownloadNotValid $windowsdownload $templatename) {return}

$result = HashAndSizeFromFileURL $windowsdownload

$hash = $result[0]
$size = $result[1]

BuildTemplate $tempfolder $templatename $hash $windowsdownload $version $description

if (!(PackAndClean $tempfolder)) {return}

NotePackageUpdate $version $verfile $templatename (GetFileSize $size)