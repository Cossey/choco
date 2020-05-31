#common functions for scripts

function BuildTemplate ($tempfolder, $name, $hash, $url, $version, $description) {
    Write-Host "Building `"$name`" templates..."
    New-Item -ItemType Directory -Path "${tempfolder}/tools" -ErrorAction Ignore | Out-Null

    Write-Host "Building nuspec template..."
    $nstemplate = Get-Content "${templates}/${name}.nuspec.template" -Raw
    $nstemplate = $nstemplate -replace "%fileversion%", "$version"
    $nstemplate = $nstemplate -replace "%description%", "$description"
    $nstemplate = $nstemplate -replace "%hash%", "$hash"
    $nstemplate = $nstemplate -replace "%downloadurl%", "$url"
    $nstemplate | Out-File "$tempfolder/${name}.nuspec"

    $files = Get-ChildItem -Path $templates -Filter "${name}_*"
    foreach ($file in $files) {
        if ($file.Name.EndsWith(".template")) {
            $outfilename = ($file.Name -replace ".{9}$" -replace ".*_")
            Write-Host "Building template '$outfilename'"
            $templater = Get-Content "${templates}/$($file.Name)" -Raw

            $templater = $templater -replace "%fileversion%", "$version"
            $templater = $templater -replace "%description%", "$description"
            $templater = $templater -replace "%hash%", "$hash"
            $templater = $templater -replace "%downloadurl%", "$url"

            
            $templater | Out-File "${tempfolder}/tools/${outfilename}"
        } else {
            $newfilename = $file.Name  -replace ".*_"
            Write-Host "Copying file '$newfilename'"
            Copy-Item "${templates}/$($file.Name)" "${tempfolder}/tools/$newfilename"
        }
    }
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
    if ("$env:debug" -ne "true") {
        Write-Host "Pack, Push and Clean `"$tempfolder`""
    } else {
        Write-Host "Pack `"$tempfolder`""
    }
    Set-Location -Path $tempfolder
    choco pack
    if ($LASTEXITCODE -ne "0") {
        if ("$env:debug" -ne "true") {
            Remove-Item -Path "$tempfolder" -Recurse -Force
        }
        return $false
    }
    if ("$env:debug" -ne "true") {
        choco push --api-key=$Env:CKEY
        if ($LASTEXITCODE -ne "0") {
            Write-Host "Retrying..."
            choco push --api-key=$Env:CKEY
            if ($LASTEXITCODE -ne "0") {
                Write-Host "Could not push to chocolatey"
                if ("$env:debug" -ne "true") {
                    Remove-Item -Path "$tempfolder" -Recurse -Force
                }
                return $false
            }
        }
    }
    Set-Location -Path $temp
    if ("$env:debug" -ne "true") {
        Remove-Item -Path "$tempfolder" -Recurse -Force
    }
    return $true
}

function JoinPath ($path) {
    $joinedpathstring += $path[0]
    for ($i=1;$i -lt $path.length; $i++) {
        if ("" -ne ("{0}" -f $path[$i]).Trim()) {
            if (!$path[$i].StartsWith("/")) {
                $joinedpathstring += "/" + $path[$i]
            } else {
                $joinedpathstring += $path[$i]
            }
        }
    }
    $joinedpathstring 
}

function GetLastVersion ($verfile) {
    Get-Content -Path "${datapath}/${verfile}" -Raw -ErrorAction Ignore
}

function GetFileSize ($bytesize) {
    "{0:N2}MB" -f ($bytesize / 1MB)
}

function ConvertDashVersion ($version, $dashpostfix) {
    $splitver = $version.Split('-')
    $res = $splitver[0] + "-" + $dashpostfix + $splitver[1]
    $res
}

function NotePackageUpdateMsg ($version, $verfile, $message) {
    $version | Out-File "${datapath}/${verfile}" -NoNewline
    SendPushover "Package Updated" "$message"
    Write-Host "Updated to `"$version`""
}

function NotePackageUpdate ($version, $verfile, $name, $size) {
    $version | Out-File "${datapath}/${verfile}" -NoNewline
    SendPushover "Package Updated" "$name updated to $version [$size]"
    Write-Host "`"$name`" updated to `"$version`" [Size: $size]"
}

function PackageError($message) {
    SendPushover "Package Error" "$message"
}

function SendPushover($title, $message) {
    if ((-not (Test-Path Env:AKEY)) -or (-not (Test-Path Env:UKEY))) {
        Write-Host "Pushover Ignored: No AKEY or UKEY provided"
    } else {
        Send-Pushover -Token $Env:AKEY -User $Env:UKEY -MessageTitle $title -Message $message
    }
}