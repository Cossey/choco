PackageName "SIRIL"

#Common Script Vars
$templatename = "siril"
$tempfolder = "$temp/$templatename/"
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

$chanagelog = [regex]::match($releasepagedata.Content, "What?'s new.*?What?'s new.*?</h2>(.*?)(<!--|</div>)", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$chanagelog = ProcessChangelog $chanagelog

$description = @"
Released $releasedate
$changelog
"@

$windows64download = [regex]::match($releasepagedata.Content, "class=`"mw-headline`".*?Windows \(64bit\)</span>.*?<ul>.*?</ul>.*?<ul>.*?<a.*? href=`"(.*?)`".*?</a>.*?</ul>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

BuildTemplate $tempfolder $templatename "" "" $version $description

if (!(ExtractZipFromURL $windows64download $tempfolder)) {return}

Move-Item -Path "$tempfolder/tools/gdbus.exe.ignore" -Destination "$tempfolder/tools/bin/gdbus.exe.ignore"
Move-Item -Path "$tempfolder/tools/gspawn-win64-helper-console.exe.ignore" -Destination "$tempfolder/tools/bin/gspawn-win64-helper-console.exe.ignore"
Move-Item -Path "$tempfolder/tools/gspawn-win64-helper.exe.ignore" -Destination "$tempfolder/tools/bin/gspawn-win64-helper.exe.ignore"
Move-Item -Path "$tempfolder/tools/siril.exe.gui" -Destination "$tempfolder/tools/bin/siril.exe.gui"

#Ignore Push errors for this - siril seems to cause HTTP524, probably due to cloudflare or chocolatey.org website.
if (!(PackAndClean $tempfolder $true)) {return}

NotePackageUpdate $version $verfile $templatename ""
