PackageName "PDF Shaper"

#Common Script Vars
$tempfolder = Join-Path $temp "ps"
$verfile = "pdfshaper.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$currentversionurl = "www.pdfshaper.com/download.html"
$whatsnewurl = "https://www.pdfshaper.com/release-notes.html"

$currentversion = Invoke-WebRequest -Uri $currentversionurl
$version = [regex]::match($currentversion.Content, "[Vv]ersion ([0-9]+\.[0-9]*)", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

if (VersionNotValid $version "pdfshaper") {return}

if (VersionNotNew $oldversion $version) {return}

$links = $currentversion.Links

Write-Host Build Download URLs...
for ($i=0; $i -lt $links.Count; $i++) {
    if ($links[$i].href -like "*cfree*") {
        $freeurl = $links[$i].href
    }
    if ($links[$i].href -like "*pro*" -and $links[$i].href -notlike "*x64*") {
        $prourl = $links[$i].href
    }
    if ($links[$i].href -like "*pro*" -and $links[$i].href -like "*x64*") {
        $prourl64 = $links[$i].href
    }
    if ($links[$i].href -like "*premium*"-and $links[$i].href -notlike "*x64*") {
        $premiumurl = $links[$i].href
    }
    if ($links[$i].href -like "*premium*"-and $links[$i].href -like "*x64*") {
        $premiumurl64 = $links[$i].href
    }
}

if ($null -eq $freeurl) {
    #Special situation for the free version
    Write-Host "PDFShaper Free URL not found on site, using special location" -ForegroundColor Green
    $freeurl = "https://www.pdfshaper.com/downloads/pdfshaper_cfree_${version}.exe"

}

#if (DownloadNotValid $freeurl "PDF Shaper Free") {return}
if (DownloadNotValid $prourl "PDF Shaper Pro") {return}
if (DownloadNotValid $premiumurl "PDF Shaper Premium") {return}
if (DownloadNotValid $prourl64 "PDF Shaper Pro") {return}
if (DownloadNotValid $premiumurl64 "PDF Shaper Premium") {return}

#if ($freeurl.StartsWith("/")) { $freeurl = "https://www.pdfshaper.com" + $freeurl }
if ($prourl.StartsWith("/")) { $prourl = "https://www.pdfshaper.com" + $prourl }
if ($premiumurl.StartsWith("/")) { $premiumurl = "https://www.pdfshaper.com" + $premiumurl }
if ($prourl64.StartsWith("/")) { $prourl64 = "https://www.pdfshaper.com" + $prourl64 }
if ($premiumurl64.StartsWith("/")) { $premiumurl64 = "https://www.pdfshaper.com" + $premiumurl64 }

#Get Changelog
$whatsnew = Invoke-WebRequest -Uri $whatsnewurl 

$releasedate = [regex]::match($whatsnew.Content, "<p class=`"text-muted`">Released (.*?)</p>").Groups[1].Value
$changelog = [regex]::match($whatsnew.Content, "Released.*?</p>(.*?)<script async", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

if (ItemEmpty $changelog "PDF Shaper" "changelog") {return}

$changelog = ProcessChangelog $changelog

$description = @"
Released $releasedate

$changelog
"@

Write-Host Release Date $releasedate

#Process Versions
Write-Host "PDF Shaper Free" -ForegroundColor Yellow
$freefilename = "pdfshaper_cfree_${version}.exe"
$freesize = DownloadInstallerFile $freeurl $freefilename

if (IncludeEULA "https://www.pdfshaper.com/eula.html" "<p class=`"lead`">(.*?)</p>") {
    if (BuildTemplate "pdfshaperfree" "" $freefilename $version $description) {
        if (!(PackAndClean)) {return}
    }
}

Write-Host "PDF Shaper Pro" -ForegroundColor Yellow
$profilename = "pdfshaper_pro_${version}.exe"
$profilename64 = "pdfshaper_pro_${version}_x64.exe"
$prosize = DownloadInstallerFile $prourl $profilename
$prosize64 = DownloadInstallerFile $prourl64 $profilename64

if (IncludeEULA "https://www.pdfshaper.com/eula.html" "<p class=`"lead`">(.*?)</p>") {
    if (BuildTemplate64 "pdfshaperpro" "" $profilename "" $profilename64 $version $description "" "") {
        if (!(PackAndClean)) {return}
    }
}

Write-Host "PDF Shaper Premium" -ForegroundColor Yellow
$premiumfilename = "pdfshaper_premium_${version}.exe"
$premiumfilename64 = "pdfshaper_premium_${version}_x64.exe"
$premiumsize = DownloadInstallerFile $premiumurl $premiumfilename
$premiumsize64 = DownloadInstallerFile $premiumurl64 $premiumfilename64

if (IncludeEULA "https://www.pdfshaper.com/eula.html" "<p class=`"lead`">(.*?)</p>") {
    if (BuildTemplate64 "pdfshaperpremium" "" $premiumfilename "" $premiumfilename64 $version $description "" "") {
        if (!(PackAndClean)) {return}
    }
}

NotePackageUpdateMsg $version $verfile "PDF Shaper Packages updated to $version`r`nFree: $(GetFileSize $freesize)`r`nPro: $(GetFileSize $prosize), $(GetFileSize $prosize64)`r`nPre: $(GetFileSize $premiumsize), $(GetFileSize $premiumsize64)"
