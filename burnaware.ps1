function BuildTemplates ($name, $hash, $url) {
    $citemplate = Get-Content "$PSScriptRoot/templates/${name}_chocolateyInstall.ps1.template" -Raw

    $citemplate = $citemplate -replace "%hash%", "$hash"
    $citemplate = $citemplate -replace "%downloadurl%", "$url"

    $citemplate | Out-File "$tempout/ba/tools/chocolateyInstall.ps1"

    $nstemplate = Get-Content "$PSScriptRoot/templates/${name}.nuspec.template" -Raw
    $nstemplate = $nstemplate -replace "%fileversion%", "$webversion"
    $nstemplate = $nstemplate -replace "%releasedate%", "$releasedate"
    $nstemplate = $nstemplate -replace "%newfeatures%", "$newfeatures"
    $nstemplate = $nstemplate -replace "%enhancements%", "$enhancements"
    $nstemplate = $nstemplate -replace "%bugfixes%", "$bugfixes"
    $nstemplate | Out-File "$tempout/ba/${name}.nuspec"
}

function DoHashing ($url) {
    Write-Host Create Folders...
    New-Item -Path $PSScriptRoot -Name "temp" -ItemType "directory" -ErrorAction Ignore | Out-Null
    New-Item -Path $tempout -Name "ba" -ItemType "directory" -ErrorAction Ignore | Out-Null
    New-Item -Path $tempout/ba -Name "tools" -ItemType "directory" -ErrorAction Ignore | Out-Null
    Write-Host Downloading Setup...
    $out = "$tempout/$webversion"
    Invoke-WebRequest -Uri $url -outfile $out
    $hash = (Get-FileHash $out).Hash
    $file = (Get-Item $out).length
    Write-Host "File Hash is $hash" -ForegroundColor Green
    Remove-Item -path $out
    return @($hash, $file)
}

function PackAndClean {
    Set-Location -Path $tempout/ba
    choco pack
    choco push --api-key=$Env:CKEY
    Set-Location -Path ..
    Set-Location -Path ..
    Remove-Item -Path $tempout -Recurse
}

$baver = $args[0]
$oldversion = Get-Content -Path "${baver}" -Raw -ErrorAction Ignore

$currentversionurl = "www.burnaware.com/download.html"
$whatsnewurl = "www.burnaware.com/whats-new.html"
$tempout = "$PSScriptRoot/temp"

$progressPreference = 'silentlyContinue'

Write-Host "===[Burnaware Package Updater]===" -ForegroundColor Yellow

Write-Host "Getting Web Version..."
$currentversion = Invoke-WebRequest -Uri $currentversionurl
$webversion = [regex]::match($currentversion.Content, "BurnAware Free.*Version (.*?)<br />", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value

# Functions


if ($oldversion -ne $webversion) {
    Write-Host "The versions $oldversion and $webversion are different!"
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

    $enhancements = [regex]::match($whatsnew.Content, "Enhancements </span>(.*?)</p>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    $enhancements = $enhancements -replace " &#8226;", "*"
    $enhancements = $enhancements -replace "<br />", ""
    $enhancements = $enhancements -replace "<br/>", ""

    $bugfixes = [regex]::match($whatsnew.Content, "Bug Fixes </span>(.*?)</p>", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
    $bugfixes = $bugfixes -replace " &#8226;", "*"
    $bugfixes = $bugfixes -replace "<br />", ""
    $bugfixes = $bugfixes -replace "<br/>", ""

    Write-Host Release Date $releasedate

    New-Item -Path . -Name "temp" -ItemType "directory" -ErrorAction Ignore | Out-Null


    #Process Versions
    Write-Host "Burnaware Free" -ForegroundColor Yellow
    $result = DoHashing $freeurl
    $freehash = $result[0]
    $freesize = $result[1]
    BuildTemplates "burnawarefree" "$freehash" "$freeurl"
    PackAndClean

    Write-Host "Burnaware Pro" -ForegroundColor Yellow
    $result = DoHashing $prourl
    $prohash = $result[0]
    $prosize = $result[1]
    BuildTemplates "burnawarepro" "$prohash" "$prourl"
    PackAndClean

    Write-Host "Burnaware Premium" -ForegroundColor Yellow
    $result = DoHashing $premiumurl
    $prehash = $result[0]
    $presize = $result[1]
    BuildTemplates "burnawarepremium" "$prehash" "$premiumurl"
    PackAndClean

    $webversion | Out-File "$baver" -NoNewline

    $FreeSizeMB = "{0:N2}MB" -f ($freesize / 1MB)
    $ProSizeMB = "{0:N2}MB" -f ($prosize / 1MB)
    $PreSizeMB = "{0:N2}MB" -f ($presize / 1MB)

    Send-Pushover -Token akxx6cbbb5g8x4rfj8tynfhdu8hwyr -User $Env:UKEY -MessageTitle "Package Updated" -Message "Burnaware Packages updated to $webversion`r`nFree: $FreeSizeMB`r`nPro: $ProSizeMB`r`nPre: $PreSizeMB"

} else {
    Write-Host "The versions $oldversion and $webversion match."
}
