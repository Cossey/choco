Write-Host "[Burnaware Package Updater]" -ForegroundColor Yellow

#Common Script Vars
$tempfolder = "$temp/ba/"
$verfile = "burnaware.ver"
$oldversion = GetLastVersion $verfile

if ($oldversion -ne "~") {
    $currentversionurl = "www.burnaware.com/download.html"
    $whatsnewurl = "www.burnaware.com/whats-new.html"

    Write-Host "Getting Web Version..."
    $currentversion = Invoke-WebRequest -Uri $currentversionurl
    $webversion = [regex]::match($currentversion.Content, "BurnAware Free.*Version (.*?)<br />", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

    if ($oldversion -ne $webversion) {
        Write-Host Build Download URLs...
        $freeurl = [regex]::match($currentversion.Content, "blockquote class=`"well`".*?href=`".*?`".*?href=`"(.*?)`"", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
        $prourl = [regex]::match($currentversion.Content, "BurnAware Professional.*?href=`"(.*?)`"", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
        $premiumurl = [regex]::match($currentversion.Content, "BurnAware Premium.*?href=`"(.*?)`"", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

        if ($freeurl.StartsWith("/")) { $freeurl = "https://www.burnaware.com" + $freeurl }
        if ($prourl.StartsWith("/")) { $prourl = "https://www.burnaware.com" + $prourl }
        if ($premiumurl.StartsWith("/")) { $premiumurl = "https://www.burnaware.com" + $premiumurl }


        #Get Changelog
        Write-Host "Getting changelog info..."
        $whatsnew = Invoke-WebRequest -Uri $whatsnewurl 

        $releasedate = [regex]::match($whatsnew.Content, "Released (.*)<br />").Groups[1].Value

        $newfeatures = [regex]::match($whatsnew.Content, "New Features </span>(.*?)</p>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
        $newfeatures = $newfeatures -replace " &#8226;", "*"
        $newfeatures = $newfeatures -replace "<br />", ""
        $newfeatures = $newfeatures -replace "<br/>", ""

        $newfeatures = (($newfeatures -Split "`n").Trim() -Join "`n")

        $enhancements = [regex]::match($whatsnew.Content, "Enhancements </span>(.*?)</p>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
        $enhancements = $enhancements -replace " &#8226;", "*"
        $enhancements = $enhancements -replace "<br />", ""
        $enhancements = $enhancements -replace "<br/>", ""

        $enhancements = (($enhancements -Split "`n").Trim() -Join "`n")

        $bugfixes = [regex]::match($whatsnew.Content, "Bug Fixes </span>(.*?)</p>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
        $bugfixes = $bugfixes -replace " &#8226;", "*"
        $bugfixes = $bugfixes -replace "<br />", ""
        $bugfixes = $bugfixes -replace "<br/>", ""

        $bugfixes = (($bugfixes -Split "`n").Trim() -Join "`n")

        $description = @"
Released $releasedate
$(if ($newfeatures) {"
New Features:"})
$newfeatures
$(if ($enhancements) {"
Enhancements:"})
$enhancements
$(if ($bugfixes) {"
Bug Fixes:"})
$bugfixes
"@

        Write-Host Release Date $releasedate

        #Process Versions
        Write-Host "Burnaware Free" -ForegroundColor Yellow
        $result = HashAndSizeFromFileURL $freeurl
        $freehash = $result[0]
        $freesize = $result[1]
        BuildTemplate $tempfolder "burnawarefree" $freehash $freeurl $webversion $description
        $packresult = PackAndClean $tempfolder

        Write-Host "Burnaware Pro" -ForegroundColor Yellow
        $result = HashAndSizeFromFileURL $prourl
        $prohash = $result[0]
        $prosize = $result[1]
        BuildTemplate $tempfolder "burnawarepro" $prohash $prourl $webversion $description
        $packresult = PackAndClean $tempfolder

        Write-Host "Burnaware Premium" -ForegroundColor Yellow
        $result = HashAndSizeFromFileURL $premiumurl
        $prehash = $result[0]
        $presize = $result[1]
        BuildTemplate $tempfolder "burnawarepremium" $prehash $premiumurl $webversion $description
        $packresult = PackAndClean $tempfolder

        NotePackageUpdateMsg $webversion $verfile "Burnaware Packages updated to $webversion`r`nFree: $(GetFileSize $freesize)`r`nPro: $(GetFileSize $prosize)`r`nPre: $(GetFileSize $presize)"
    } else {
        Write-Host "No New Version"
    }
} else {
    Write-Host "Skip Updating Package" 
}
