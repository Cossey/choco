Write-Host "[ROCCAT Swarm Package Updater]" -ForegroundColor Yellow

#Common Script Vars
$templatename = "roccatswarm"
$tempfolder = "$temp/roccatswarm/"
$verfile = "roccatswarm.ver"
$oldversion = GetLastVersion $verfile

if ($oldversion -ne "~") {
    $downloadpagehtml = (Invoke-WebRequest "https://en.roccat.org/Support/Product/ROCCAT-Swarm").Content

    $downloaddatahtml = [regex]::match($downloadpagehtml, "<div id=`"Downloads`">(.*?)<span>Previous versions:</span>")

    $version = [regex]::match($downloaddatahtml, "class=`"Version`".*?<span>V:(.*?)</span>").Groups[1].Value

    if ($oldversion -ne $version) {
        $baseurl = [regex]::match($downloadpagehtml, "<base href=`"(.*?)`">").Groups[1].Value

        $downloadurlraw = [regex]::match($downloaddatahtml, "<button name=`"download`".*?value=`"(.*?)`"").Groups[1].Value
        $changelog = [regex]::match($downloaddatahtml, "Changelog:</span></div>(.*?)<div class=`"Dropdown`">").Groups[1].Value

        #Process Changelog into friendly format for nuspec file
        $changelog = $changelog -replace "<div>", ""
        $changelog = $changelog -replace "</div>", ""
        $changelog = $changelog -replace "<b>-</b>", "*"
        $changelog = $changelog -replace "<p>", ""
        $changelog = $changelog -replace "</p>", "`n"
        $changelog = (($changelog -Split "`n").Trim() -Join "`n")

        $downloadurl = JoinPath(@($baseurl, $downloadurlraw))

        $fileinfo = HashAndSizeFromFileURL $downloadurl
        $filehash = $fileinfo[0]
        $filesize = $fileinfo[1]

        BuildTemplate $tempfolder $templatename $filehash $downloadurl $version $changelog
        PackAndClean $tempfolder
        NotePackageUpdate $version $verfile $templatename (GetFileSize $filesize)
    } else {
        Write-Host "No New Version"
    }
} else {
    Write-Host "Skip Updating Package" 
}
