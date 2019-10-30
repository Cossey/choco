function BuildTemplates ($name, $hash, $url, $ver, $rls) {
    $citemplate = Get-Content "$PSScriptRoot/templates/${name}_chocolateyInstall.ps1.template" -Raw

    $citemplate = $citemplate -replace "%hash%", "$hash"
    $citemplate = $citemplate -replace "%downloadurl%", "$url"

    $citemplate | Out-File "$tempout/ao/tools/chocolateyInstall.ps1"

    $nstemplate = Get-Content "$PSScriptRoot/templates/${name}.nuspec.template" -Raw
    $nstemplate = $nstemplate -replace "%fileversion%", "$ver"
    $nstemplate = $nstemplate -replace "%releasedate%", "$rls"
    $nstemplate | Out-File "$tempout/ao/${name}.nuspec"
}

function DoHashing ($url, $webversion) {
    Write-Host Create Folders...
    New-Item -Path $PSScriptRoot -Name "temp" -ItemType "directory" -ErrorAction Ignore | Out-Null
    New-Item -Path $tempout -Name "ao" -ItemType "directory" -ErrorAction Ignore | Out-Null
    New-Item -Path $tempout/ao -Name "tools" -ItemType "directory" -ErrorAction Ignore | Out-Null
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
    Set-Location -Path $tempout/ao
    choco pack
    choco push --api-key=$Env:CKEY
    Set-Location -Path ..
    Set-Location -Path ..
    Remove-Item -Path $tempout -Recurse
}

$sver = $args[0]
$tver = $args[1]
$oldsoloversion = Get-Content -Path "${sver}" -Raw -ErrorAction Ignore
$oldteamversion = Get-Content -Path "${tver}" -Raw -ErrorAction Ignore

$progressPreference = 'silentlyContinue'
$tempout = "$PSScriptRoot/temp"

Write-Host "===[Acarda Outbound Package Updater]===" -ForegroundColor Yellow

Write-Host "Getting files list..."

$installfilesurl = "https://www.acarda.com/wp-content/themes/divi-child/js/installs_data.js"
$installfiles = Invoke-WebRequest -Uri $installfilesurl



Write-Host "Parsing solo..."
$solofilesraw = [regex]::match($installfiles.Content, "getSoloInstalls = (.*?);", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$solofilesjson = ConvertFrom-Json -InputObject $solofilesraw
$solowebversion = $solofilesjson.current.version
$soloreleasedate = $solofilesjson.current.date
$solourl = $solofilesjson.current.url

if ($oldsoloversion -ne $solowebversion) {
    Write-Host "The solo versions $oldsoloversion and $solowebversion are different!"

    Write-Host Release Date $soloreleasedate

    New-Item -Path . -Name "temp" -ItemType "directory" -ErrorAction Ignore | Out-Null

    $result = DoHashing $solourl $solowebversion
    $solohash = $result[0]
    $solosize = $result[1]
    $SoloSizeMB = "{0:N2}MB" -f ($solosize / 1MB)
    BuildTemplates "acardasolo" "$solohash" "$solourl" "$solowebversion" "$soloreleasedate"
    PackAndClean

    $solowebversion | Out-File "$sver" -NoNewline

    Send-Pushover -Token akxx6cbbb5g8x4rfj8tynfhdu8hwyr -User $Env:UKEY -MessageTitle "Package Updated" -Message "Acarda Outbound Solo`r`nTo: $solowebversion`r`nFrom: $oldsoloversion`r`nSize: $SoloSizeMB"

} else {
    Write-Host "The solo versions $oldsoloversion and $solowebversion match."
}


Write-Host "Parsing agent..."
$teamfilesraw = [regex]::match($installfiles.Content, "getTeamInstalls = (.*?);", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$teamfilesjson = ConvertFrom-Json -InputObject $teamfilesraw
$teamcurrent = ($teamfilesjson.current | Where-Object { $_.name -eq "Acarda Outbound Agent Setup" })
$teamwebversion = $teamcurrent.version
$teamreleasedate = $teamcurrent.date
$teamurl = $teamcurrent.url

if ($oldteamversion -ne $teamwebversion) {
    Write-Host "The agent versions $oldversion and $teamwebversion are different!"

    Write-Host Release Date $teamcurrent.date

    New-Item -Path . -Name "temp" -ItemType "directory" -ErrorAction Ignore | Out-Null

    $result = DoHashing $teamurl $teamwebversion
    $agenthash = $result[0]
    $agentsize = $result[1]
    $AgentSizeMB = "{0:N2}MB" -f ($agentsize / 1MB)
    BuildTemplates "acardaagent" "$agenthash" "$teamurl" "$teamwebversion" "$teamreleasedate"
    PackAndClean

    $teamwebversion | Out-File "$tver" -NoNewline

    Send-Pushover -Token akxx6cbbb5g8x4rfj8tynfhdu8hwyr -User $Env:UKEY -MessageTitle "Package Updated" -Message "Acarda Outbound Agent`r`nTo: $teamwebversion`r`nFrom: $oldteamversion`r`nSize: $AgentSizeMB"

} else {
    Write-Host "The agent versions $oldteamversion and $teamwebversion match."
}