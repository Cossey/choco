#common functions for scripts

function BuildTemplate ($tempfolder, $name, $hash, $url, $version, $description) {
    return (BuildTemplate64 $tempfolder $name $hash $url $null $null $version $description "" "")
}

function BuildTemplateParam ($tempfolder, $name, $hash, $url, $version, $description, $param1, $param2) {
    return (BuildTemplate64 $tempfolder $name $hash $url $null $null $version $description $param1 $param2)
}

function BuildTemplate64 ($tempfolder, $name, $hash, $url, $hash64, $url64, $version, $description, $param1, $param2) {

    Write-Host "Validating variables..."
    if ($null -eq $hash) {
        PackageError "$name has empty hash"
        return $false
    }

    if ($null -eq $url) {
        PackageError "$name has empty url"
        return $false
    }


    Write-Host "Building `"$name`" templates..."
    New-Item -ItemType Directory -Path "${tempfolder}/tools" -ErrorAction Ignore | Out-Null

    Write-Host "Building nuspec template..."
    $nstemplate = Get-Content "${templates}/${name}.nuspec.template" -Raw
    $nstemplate = $nstemplate -replace "%fileversion%", "$version"
    $nstemplate = $nstemplate -replace "%description%", "$description"
    $nstemplate = $nstemplate -replace "%hash%", "$hash"
    $nstemplate = $nstemplate -replace "%downloadurl%", "$url"
    $nstemplate = $nstemplate -replace "%param1%", "$param1"
    $nstemplate = $nstemplate -replace "%param2%", "$param2"

    if ($hash64 -and $url64) {
        $nstemplate = $nstemplate -replace "%hash64%", "$hash64"
        $nstemplate = $nstemplate -replace "%downloadurl64%", "$url64"
    }

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
            $templater = $templater -replace "%param1%", "$param1"
            $templater = $templater -replace "%param2%", "$param2"

            if ($hash64 -and $url64) {
                $templater = $templater -replace "%hash64%", "$hash64"
                $templater = $templater -replace "%downloadurl64%", "$url64"
            }
            
            $templater | Out-File "${tempfolder}/tools/${outfilename}"
        } else {
            $newfilename = $file.Name -replace ".*_"
            Write-Host "Copying file '$newfilename'"
            Copy-Item "${templates}/$($file.Name)" "${tempfolder}/tools/$newfilename"
        }
    }

    return $true
}

function DownloadFile($url, $out) {
    Write-Host "Downloading File to `"$out`"..."
    
    Invoke-WebRequest -Uri $url -outfile $out

    $hash = (Get-FileHash $out).Hash
    $file = (Get-Item $out).Length

    Write-Host "File Size `"$file`" Hash `"$hash`"" -ForegroundColor Green
    
    return @($hash, $file)
}

function HashSizeAndContentsFromZipFileURL ($url) {
    $randomstring = (-join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_}))
    New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
    $out = "${temp}/${randomstring}"

    Write-Host "Downloading Zip File to `"$out`"..."
    Invoke-WebRequest -Uri $url -outfile $out
    $hash = (Get-FileHash $out).Hash
    $filesize = (Get-Item $out).Length
    
    $zip = [IO.Compression.ZipFile]::OpenRead($out)
    $filelist = $zip.Entries
    $zip.Dispose()
    Write-Host "File Size `"$filesize`" Hash `"$hash`" File Count $($filelist.Count)" -ForegroundColor Green
    if ("$env:debug" -ne "true") {
        Remove-Item -path $out
        Write-Host "Removed temporary file `"$out`""
    }
    return @($hash, $filesize, $filelist)
}

function HashAndSizeFromFileURL ($url) {         
    $randomstring = (-join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_}))

    New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
    $out = "${temp}/${randomstring}"

    Write-Host "Downloading File to `"$out`"..."
    Invoke-WebRequest -Uri $url -outfile $out
    $hash = (Get-FileHash $out).Hash
    $filesize = (Get-Item $out).Length
    Write-Host "File Size `"$filesize`" Hash `"$hash`"" -ForegroundColor Green
    if ("$env:debug" -ne "true") {
        Remove-Item -path $out
        Write-Host "Removed temporary file `"$out`""
    }
    return @($hash, $filesize)
}

function ExtractZipFromURL ($url, $tempfolder) {
    $randomstring = (-join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_}))
    $out = "${temp}/${randomstring}"
    try {
        New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
        Write-Host "Downloading File to `"$out`"..."
        Invoke-WebRequest -Uri $url -outfile $out
        $size = (Get-Item $out).length
        Write-Host "Downloaded File - $size bytes, Extracting file..."
        [System.IO.Compression.ZipFile]::ExtractToDirectory($out, "${tempfolder}/tools")
        Write-Host "Extraction complete"
        
        Write-Host "Removed temporary file `"$out`""
        return $true
    }
    catch {
        Write-Host "Error Extracting Zip From `"$url`""
        PackageError "Package: $tempfolder`nError Extracting from URL: $url"
        return $false
    } finally {
        Remove-Item -Path $out
    }
}

function PackAndClean ($tempfolder, $ignorepushresult) {
    Set-Location -Path "$tempfolder"
    Write-Host "Packing `"$tempfolder`"..."
    $result = (choco pack)
    if ($LASTEXITCODE -ne "0") {
        if ("$env:debug" -ne "true") {
            Write-Host "Pack return exit code $LASTEXITCODE`n-----------`n$result`n-----------"
            Remove-Item -Path "$tempfolder" -Recurse -Force
        }
        return $false
    }
    if ("$env:debug" -ne "true") {
        Write-Host "Pushing..."
        $result = (choco push --api-key=$Env:CKEY)
        if ($LASTEXITCODE -ne "0") {
            Write-Host "Exit code $LASTEXITCODE`n-----------`n$result`n----------`nRetrying..."
            $result = (choco push --api-key=$Env:CKEY)
            if ($LASTEXITCODE -ne "0") {
                Write-Host "Could not push to chocolatey. Exit code $LASTEXITCODE`n----------`n$result`n----------"

                if (($null -eq $ignorepushresult -or $ignorepushresult -ne "true")) {
                    Write-Host "Assume Package success due to override."
                } else {
                    
                    if ("$env:debug" -ne "true") {
                        Write-Host "Cleaning..."
                        Remove-Item -Path "$tempfolder" -Recurse -Force
                    }
                    return $false
                }
            }
        }
    }
    Set-Location -Path $temp
    if ("$env:debug" -ne "true") {
        Write-Host "Cleaning..."
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

function ItemEmpty ($obj, $packagename, $objname) {
    if ($obj -eq "") {
        PackageError "Package: $packagename`nEmpty Var: $objname"
        return $true
    } 
    return $false
}

function ItemNotDefined ($obj, $packagename, $objname) {
    if ($null -eq $obj) {
        PackageError "Package: $packagename`nNull Var: $objname"
        return $true
    } 
    return $false
}

function PackageName ($title) {
    Write-Host "[PACKAGE $title UPDATER]" -ForegroundColor Yellow
}

function CheckSkip ($version) {
    if ($version -eq "~") {
        Write-Host "Skip Updating Package"
        return $true
    }
    return $false
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
    if ("$env:debug" -ne "true") {
        $version | Out-File "${datapath}/${verfile}" -NoNewline
    }
    SendPushover "Package Updated" "$message"
    Write-Host "Updated to `"$version`""
}

function NotePackageUpdate ($version, $verfile, $name, $size) {
    if ("$env:debug" -ne "true") {
        $version | Out-File "${datapath}/${verfile}" -NoNewline
    }
    if ($null -eq $size) {
        Write-Host "`"$name`" updated to `"$version`" [Size: $size]"
        SendPushover "Package Updated" "$name updated to $version [$size]"
    } else {
        Write-Host "`"$name`" updated to `"$version`""
        SendPushover "Package Updated" "$name updated to $version"
    }
}

function PackageError($message) {
    Write-Host "ERROR: $message"
    SendPushover "Package Error" "$message"
}

function VersionNotNew($oldversion, $newversion) {
    if ($oldversion -eq $newversion) {
        Write-Host "No New Version"
        return $true
    }
    return $false
}

function VersionNotValid($version, $packagename) {
    if ($version -match "[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:\.[0-9]+?|\-[a-z]+[0-9]+)?") {
        return $false
    }
    Write-Host "Cannot validate version number"
    PackageError "Package: $packagename`nInvalid Version: $version"
    return $true
}

function DownloadNotValid($url, $packagename) {
    if ($null -eq $url) {
        Write-Host "URL is invalid"
        PackageError "Package: $packagename`nURL Empty"
        return $true
    }
    return $false
}

function SendPushover($title, $message) {
    if ((-not (Test-Path Env:AKEY)) -or (-not (Test-Path Env:UKEY))) {
        Write-Host "Pushover Ignored: No AKEY or UKEY provided"
    } else {
        Send-Pushover -Token $Env:AKEY -User $Env:UKEY -MessageTitle $title -Message $message
    }
}

function ProcessChangelog ($data) {
    $data = $data -Replace '(?ms)<a.*?>(.*?)</a>','$1'  #Remove any link tags and replace with the links inner text
    $data = $data -Replace "</li>","" #Remove closing li tag
    $data = $data -Replace "<li>","*" #Convert to *
    $data = $data -replace "&#8226;", "*" #Convert to *
    $data = $data -replace "<b>-</b>", "*" #Convert to *
    $data = $data -replace "<br />", "" #Remove line break tag
    $data = $data -replace "<br/>", "" #Remove line break tag
    $data = $data -replace "</p>", "" #Remove closing p tag
    $data = $data -replace "<ul>", "" #Remove ul tag
    $data = $data -replace "</ul>", "" #Remove ul tag
    $data = $data -replace "</span>", "" #Remove span tag
    $data = $data -replace "<span.*?>", "" #Remove span tag
    $data = $data -replace "<div.*?>", "" #Remove div tag
    $data = $data -replace "</div>", "" #Remove div tag
    $data = $data -creplace '(?m)^\s*\r?\n','' #Remove any * on lines of their own
    
    $data = $data -Replace "<h1>","# "
    $data = $data -Replace "<h2>","## "
    $data = $data -Replace "</h1>",""
    $data = $data -Replace "</h2>",""

    $data = $data -creplace '(?m)^\*\S+','*' #Make sure any lines starting with * has one whitespace character after
    $data = $data -replace "<p>", "`n" #Make sure any P tag creates a new line
    $data = (($data -Split "`n").Trim() -Join "`n") #Split all lines, trim them and then rejoin them
    if ("$env:debug" -eq "true") {
        Write-Host "Changelog Process:`n$data`n----------"
    }
    return $data
}
