#common functions for scripts
function BuildTemplate ($tempfolder, $name, $hash, $url, $version, $description) {
    Write-Host "Building `"$name`" templates..."
    New-Item -ItemType Directory -Path "${tempfolder}/tools" -ErrorAction Ignore | Out-Null

    $citemplate = Get-Content "${templates}/${name}_chocolateyInstall.ps1.template" -Raw

    $citemplate = $citemplate -replace "%hash%", "$hash"
    $citemplate = $citemplate -replace "%downloadurl%", "$url"

    $citemplate | Out-File "${tempfolder}/tools/chocolateyInstall.ps1"

    $nstemplate = Get-Content "${templates}/${name}.nuspec.template" -Raw
    $nstemplate = $nstemplate -replace "%fileversion%", "$version"
    $nstemplate = $nstemplate -replace "%description%", "$description"
    $nstemplate | Out-File "$tempfolder/${name}.nuspec"
}

function HashAndSizeFromFileURL ($url) {
    $randomstring = (-join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_}))

    New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
    $out = "${temp}/${randomstring}"
    Write-Host "Downloading File to `"$out`"..."
    Invoke-WebRequest -Uri $url -outfile $out
    $hash = (Get-FileHash $out).Hash
    $file = (Get-Item $out).length
    Write-Host "File Size `"$file`" Hash `"$hash`"" -ForegroundColor Green
    Remove-Item -path $out
    return @($hash, $file)
}

function PackAndClean ($tempfolder) {
    Write-Host "Pack, Push and Clean `"$tempfolder`""
    Set-Location -Path $tempfolder
    choco pack
    choco push --api-key=$Env:CKEY
    Set-Location -Path $temp
    Remove-Item -Path $tempfolder -Recurse
}

function GetLastVersion ($verfile) {
    Get-Content -Path "${datapath}/${verfile}" -Raw -ErrorAction Ignore
}

function GetFileSize ($bytesize) {
    "{0:N2}MB" -f ($bytesize / 1MB)
}

function NotePackageUpdateMsg ($version, $verfile, $message) {
    $version | Out-File "${datapath}/${verfile}" -NoNewline
    Send-Pushover -Token $Env:AKEY -User $Env:UKEY -MessageTitle "Package Updated" -Message "$message"
}

function NotePackageUpdate ($version, $verfile, $name, $size) {
    $version | Out-File "${datapath}/${verfile}" -NoNewline
    Send-Pushover -Token $Env:AKEY -User $Env:UKEY -MessageTitle "Package Updated" -Message "$name updated to $version [$size]"
    Write-Host "`"$name`" updated to `"$version`" [Size: $size]"
}