PackageName "Burnaware"

#Common Script Vars
$tempfolder = Join-Path $temp "ba"
$verfile = "burnaware.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

$currentversionurl = "www.burnaware.com/download.html"
$whatsnewurl = "www.burnaware.com/whats-new.html"

$currentversion = Invoke-WebRequest -Uri $currentversionurl
$version = [regex]::match($currentversion.Content, "[Vv]ersion ([0-9]+\.[0-9]*)", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

if (VersionNotValid $version "burnaware") {return}

if (VersionNotNew $oldversion $version) {return}

$links = $currentversion.Links

Write-Host Build Download URLs...
for ($i=0; $i -lt $links.Count; $i++) {
    if ($links[$i].href -like "*cfree*") {
        $freeurl = $links[$i].href
    }
    if ($links[$i].href -like "*pro*") {
        $prourl = $links[$i].href
    }
    if ($links[$i].href -like "*premium*") {
        $premiumurl = $links[$i].href
    }
}

if (DownloadNotValid $freeurl "Burnaware Free") {return}
if (DownloadNotValid $prourl "Burnaware Pro") {return}
if (DownloadNotValid $premiumurl "Burnaware Premium") {return}

if ($freeurl.StartsWith("/")) { $freeurl = "https://www.burnaware.com" + $freeurl }
if ($prourl.StartsWith("/")) { $prourl = "https://www.burnaware.com" + $prourl }
if ($premiumurl.StartsWith("/")) { $premiumurl = "https://www.burnaware.com" + $premiumurl }

#Get Changelog
$whatsnew = Invoke-WebRequest -Uri $whatsnewurl 

$releasedate = [regex]::match($whatsnew.Content, "Released (.*)</small>").Groups[1].Value
$changelog = [regex]::match($whatsnew.Content, "Released.*?<p.*?>(.*?)</p>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

if (ItemEmpty $changelog "Burnaware" "changelog") {return}

$changelog = ProcessChangelog $changelog



$description = @"
Released $releasedate

$changelog
"@

Write-Host Release Date $releasedate

#Process Versions
Write-Host "Burnaware Free" -ForegroundColor Yellow
$result = HashAndSizeFromFileURL $freeurl
$freehash = $result[0]
$freesize = $result[1]
BuildTemplate $tempfolder "burnawarefree" $freehash $freeurl $version $description
if (!(PackAndClean $tempfolder)) {return}

Write-Host "Burnaware Pro" -ForegroundColor Yellow
$result = HashAndSizeFromFileURL $prourl
$prohash = $result[0]
$prosize = $result[1]
BuildTemplate $tempfolder "burnawarepro" $prohash $prourl $version $description
if (!(PackAndClean $tempfolder)) {return}

Write-Host "Burnaware Premium" -ForegroundColor Yellow
$result = HashAndSizeFromFileURL $premiumurl
$prehash = $result[0]
$presize = $result[1]
BuildTemplate $tempfolder "burnawarepremium" $prehash $premiumurl $version $description
if (!(PackAndClean $tempfolder)) {return}

NotePackageUpdateMsg $version $verfile "Burnaware Packages updated to $version`r`nFree: $(GetFileSize $freesize)`r`nPro: $(GetFileSize $prosize)`r`nPre: $(GetFileSize $presize)"
