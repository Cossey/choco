PackageName "SIRIL"

#Common Script Vars
$templatename = "siril"
$tempfolder = Join-Path $temp $templatename
$verfile = "$templatename.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$releasespage = Invoke-WebRequest -Uri "https://free-astro.org/index.php?title=Siril:releases"
$releaseslinks = $releasespage.Links | Where-Object { $_.HRef -match "Siril:[0-9.]+" }
$releaseurl = $releaseslinks[0].HRef

$version = [regex]::match($releaseurl, "Siril:([0-9.]*)").Groups[1].Value

Write-Host "Latest version: $version"

if (VersionNotValid $version $templatename) {return}

if (VersionNotNew $oldversion $version) {return}

if ($releaseurl.StartsWith("/")) {
    $releaseurl = "https://free-astro.org" + $releaseurl
}

$releasepagedata = Invoke-WebRequest -Uri "$releaseurl"
$releasedate = ([regex]::match($releasepagedata.Content, "<b>Release date: (.*?)</b>").Groups[1].Value).Trim()

Write-Host Release Date $releasedate

$changelog = [regex]::match($releasepagedata.Content, "What?'s new.*?</h2>(.*?)(<!--|</div>)", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

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

if (!(BuildTemplate $templatename $hash $windowsdownload $version $description)) {return}

if (!(PackAndClean)) {return}

NotePackageUpdate $version $verfile $templatename (GetFileSize $size)