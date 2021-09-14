#common functions for scripts

function LoadEnvVars () {
    Set-Variable -Name "DEBUG" -Value $env:debug -Scope global
    
    if ($DEBUG -ne "false" -and $DEBUG -ne "true") {
        Write-Host "DEBUG must be true or false"
        exit -2
    }
     
    DebugOut "DEBUGGING IS ENABLED!"

    LoadEnvVar "DELAY"
    LoadEnvVar "MAX_PUSH_ATTEMPTS" 1
    LoadEnvVar "CKEY"
    LoadEnvVar "AKEY"
    LoadEnvVar "UKEY"

    if ($DELAY -and $DELAY -notmatch "[0-9]+") {
        Write-Host "DELAY must be a number"
        exit -2
    }

    if ($MAX_PUSH_ATTEMPTS -and $MAX_PUSH_ATTEMPTS -notmatch "[0-9]+") {
        Write-Host "MAX_PUSH_ATTEMPTS must be a number"
        exit -2
    }

    if ($CKEY -and $CKEY -notmatch "(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$") {
        Write-Host "CKEY must be a valid API key"
        exit -2
    }

    if ($AKEY -and $AKEY.length -ne 30) {
        Write-Host "AKEY must be a valid API key"
        exit -2
    }

    if ($UKEY -and $UKEY.length -ne 30) {
        Write-Host "UKEY must be a valid API key"
        exit -2
    }

}

function LoadEnvVar ($var, $default) {
    try {
        $val = (Get-Item env:"$var" -ErrorAction Ignore).Value
    }
    catch {}
    try {
        $val_file = (Get-Item env:"${var}_FILE" -ErrorAction Ignore).Value
    }
    catch {}

    if ($val -and $val_file) {
        Write-Host "Variable $var and ${var}_FILE are both defined!"
        exit -1
    }

    DebugOut "Variable $var Value $val File $val_file"

    if (-not $val -and -not $val_file) {
        Set-Variable -Name $var -Value $default -Scope global
    }
    else {
        if ($val_file) {
            $filedata = (Get-Content $val_file -Raw -ErrorAction Ignore)
            DebugOut "File $val_file Data $filedata"
            Set-Variable -Name $var -Value $filedata -Scope global
        }
        else {
            Set-Variable -Name $var -Value $val -Scope global
        }
    }
}

function BuildTemplate ($name, $hash, $url, $version, $description) {
    return (BuildTemplate64 $name $hash $url $null $null $version $description "" "")
}

function BuildTemplateParam ($name, $hash, $url, $version, $description, $param1, $param2) {
    return (BuildTemplate64 $name $hash $url $null $null $version $description $param1 $param2)
}

function BuildTemplate64 ($name, $hash, $url, $hash64, $url64, $version, $description, $param1, $param2) {

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
    New-Item -ItemType Directory -Path $(Join-Path "${tempfolder}" "tools") -ErrorAction Ignore | Out-Null

    Write-Host "Building nuspec template..."
    $nstemplate = Get-Content $(Join-Path "${templates}" "${name}.nuspec.template") -Raw
    $nstemplate = $nstemplate -replace "%fileversion%", "$version"
    $nstemplate = $nstemplate -replace "%description%", "$description"
    $nstemplate = $nstemplate -replace "%hash%", "$hash"
    $nstemplate = $nstemplate -replace "%downloadurl%", "$url"
    $nstemplate = $nstemplate -replace "%param1%", "$param1"
    $nstemplate = $nstemplate -replace "%param2%", "$param2"
    $nstemplate = $nstemplate -replace "%toolsfilepath%", "$(Join-Path "tools" "**")"
    $nstemplate = $nstemplate -replace "%copyrightyear%", "$(Get-Date -format yyyy)"

    $nstemplate = $nstemplate -replace "%hash64%", "$hash64"
    $nstemplate = $nstemplate -replace "%downloadurl64%", "$url64"

    $nstemplate | Out-File $(Join-Path "$tempfolder" "${name}.nuspec")

    $files = Get-ChildItem -Path $templates -Filter "${name}_*"
    foreach ($file in $files) {
        if ($file.Name.EndsWith(".template")) {
            $outfilename = ($file.Name -replace ".{9}$" -replace ".*_")
            Write-Host "Building template '$outfilename'"
            $templater = Get-Content $(Join-Path "${templates}" "$($file.Name)") -Raw

            $templater = $templater -replace "%fileversion%", "$version"
            $templater = $templater -replace "%description%", "$description"
            $templater = $templater -replace "%hash%", "$hash"
            $templater = $templater -replace "%downloadurl%", "$url"
            $templater = $templater -replace "%param1%", "$param1"
            $templater = $templater -replace "%param2%", "$param2"

            $templater = $templater -replace "%hash64%", "$hash64"
            $templater = $templater -replace "%downloadurl64%", "$url64"
            
            $templater | Out-File $(Join-Path "${tempfolder}" "tools" "${outfilename}")
        }
        else {
            $newfilename = $file.Name -replace ".*_"
            Write-Host "Copying file '$newfilename'"
            Copy-Item $(Join-Path "${templates}" "$($file.Name)") $(Join-Path "${tempfolder}" "tools" "$newfilename")
        }
    }

    return $true
}

function IncludeEULA($url, $regexparse) {
    $eula = Invoke-WebRequest -Uri $url
    if ($eula.StatusCode -ne 200) {
        PackageError "Failed to download EULA from $url"
        return $false
    }
    
    $eula = $eula.Content

    if ($regexparse) {
        $eula = [regex]::Match($eula, $regexparse, [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
        $eula = ProcessChangelog $eula $true $true
        $licensefile = "LICENSE.md"
    }
    else {
        $licensefile = "LICENSE.txt"
        DebugOut "EULA: $eula"
    }

    if ($eula.trim().length -eq 0) {
        Write-Host "Failed to parse EULA from $url"
        return $false
    }

    $eulapath = Join-Path "${tempfolder}" "tools" "$licensefile"
    $eula | Out-File -Path $eulapath
    return $true
}

function IncludeFrom7zURL($url) {
    $dlpath = Join-Path "${tempfolder}" "tools"
    $randomstring = ( -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ }))
    New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
    $out = $(Join-Path "${temp}" "${randomstring}")

    Write-Host "Downloading 7z file at $url to $out..."
    Invoke-WebRequest -Uri $url -outfile $out

    $result = 7z x $out -o"${dlpath}" -t7z -y

    if ($LASTEXITCODE -ne "0") {
        PackageError "Error $LASTEXITCODE extracting 7z file for $tempfolder"
        return $false
    }
    return $true
}

function RemoveSubfolder() {
    $tpath = Join-Path "${tempfolder}" "tools"
    $filelist = Get-ChildItem -Path $tpath -File -ErrorAction Ignore
    $folderlist = Get-ChildItem -Path $tpath -Directory -ErrorAction Ignore

    if ($filelist.Length -eq 0 -and $folderlist.Length -eq 1) {
        Write-Host "Shifting Files..."
        Move-Item -Path $(Join-Path ${folderlist} "*") -Destination $tpath -Force -ErrorAction Ignore
        Remove-Item -Path ${folderlist} -ErrorAction Ignore
    }
}

function DownloadInstallerFile($url, $filename) {
    $dlpath = Join-Path "${tempfolder}" "tools"
    $fullpath = Join-Path $dlpath $filename
    New-Item -ItemType Directory -Path $dlpath -ErrorAction Ignore | Out-Null

    Write-Host "Download installer file at $url to $fullpath"
    
    Invoke-WebRequest -Uri $url -outfile $fullpath

    $filesize = (Get-Item $fullpath).Length

    #create ignore for installer to stop it from being shimmed
    New-Item "$fullpath.ignore" -type file -force | Out-Null

    Write-Host "File Size `"$filesize`"" -ForegroundColor Green
    
    return $filesize
}

function DownloadFile($url, $out) {
    Write-Host "Downloading File to `"$out`"..."
    
    Invoke-WebRequest -Uri $url -outfile $out

    $hash = (Get-FileHash $out).Hash
    $file = (Get-Item $out).Length

    DebugOut "File Size `"$file`" Hash `"$hash`""
    
    return @($hash, $file)
}

function HashSizeAndContentsFromZipFileURL ($url) {
    $randomstring = ( -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ }))
    New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
    $out = $(Join-Path "${temp}" "${randomstring}")

    Write-Host "Downloading Zip File to `"$out`"..."
    Invoke-WebRequest -Uri $url -outfile $out
    $hash = (Get-FileHash $out).Hash
    $filesize = (Get-Item $out).Length
    
    $zip = [IO.Compression.ZipFile]::OpenRead($out)
    $filelist = $zip.Entries
    $zip.Dispose()
    DebugOut "File Size `"$filesize`" Hash `"$hash`" File Count $($filelist.Count)"
    if ("$debug" -ne "true") {
        Remove-Item -path $out
        Write-Host "Removed temporary file `"$out`""
    }
    return @($hash, $filesize, $filelist)
}

function HashAndSizeFromFileURL ($url) {         
    $randomstring = ( -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ }))

    New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
    $out = $(Join-Path "${temp}" "${randomstring}")

    Write-Host "Downloading File to `"$out`"..."
    Invoke-WebRequest -Uri $url -outfile $out
    $hash = (Get-FileHash $out).Hash
    $filesize = (Get-Item $out).Length
    DebugOut "File Size `"$filesize`" Hash `"$hash`""
    if ("$debug" -ne "true") {
        Remove-Item -path $out
        Write-Host "Removed temporary file `"$out`""
    }
    return @($hash, $filesize)
}

function ExtractZipFromURL ($url) {
    $randomstring = ( -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ }))
    $out = $(Join-Path "${temp}" "${randomstring}")
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
    }
    finally {
        Remove-Item -Path $out
    }
}

function DoPush ($attempt, $backoff) {
    $attempt = ($attempt + 1)
    if ($null -eq $backoff) {
        $backoff = 60
    }
    else {
        $backoff = $backoff * 2
    }

    Write-Host "Pushing..."
    $result = (choco push --api-key=$CKEY -dv)
    if ($LASTEXITCODE -ne "0") {
        Write-Host "Exit code $LASTEXITCODE at $(Get-Date)`n-----------`n$result`n----------"
        if ($attempt -gt $MAX_PUSH_ATTEMPTS) {
            PackageError "Failed to push package $tempfolder after $maxattempts attempts"
            return $false
        }
        else {
            Write-Host "Retrying in $($backoff / 60) minutes..."
            Start-Sleep -Seconds $backoff
            DoPush $attempt $backoff
        }
    }
    return $true
}

function PackAndClean ($ignorepushresult) {
    Set-Location -Path "$tempfolder"
    Write-Host "Packing `"$tempfolder`"..."
    $result = (choco pack)
    if ($LASTEXITCODE -ne "0") {
        if ("$debug" -ne "true") {
            Write-Host "Pack return exit code $LASTEXITCODE at $(Get-Date)`n-----------`n$result`n-----------"
            PackageError "Package $tempfolder Pack Error`n$result"
            Remove-Item -Path "$tempfolder" -Recurse -Force
        }
        return $false
    }
    if ("$debug" -ne "true") {
        if (DoPush 0) {
            Write-Host "Push successfull"
        } else {
            if ("$debug" -ne "true") {
                Write-Host "Cleaning..."
                Remove-Item -Path "$tempfolder" -Recurse -Force
            }
            return $false
        }
    }
    Set-Location -Path $temp
    if ("$debug" -ne "true") {
        Write-Host "Cleaning..."
        Remove-Item -Path "$tempfolder" -Recurse -Force
    }
    return $true
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
    Write-Host "[$title]" -ForegroundColor Yellow
}

function CheckSkip ($version) {
    if ($version -eq "~") {
        Write-Host "Skip Updating Package"
        return $true
    }
    return $false
}

function GetLastVersion ($verfile) {
    Get-Content -Path $(Join-Path "${datapath}" "${verfile}") -Raw -ErrorAction Ignore
}

function GetFileSize ($bytesize) {
    return (($bytesize / 1MB).ToString("0.00") + "MB")
}

function ConvertDashVersion ($version, $dashpostfix) {
    $splitver = $version.Split('-')
    $res = $splitver[0] + "-" + $dashpostfix + $splitver[1]
    $res
}

function NotePackageUpdateMsg ($version, $verfile, $message) {
    if ("$debug" -ne "true") {
        $version | Out-File $(Join-Path "${datapath}" "${verfile}") -NoNewline
    }
    SendPushover "Package Updated" "$message"
    Write-Host "Updated to `"$version`""
}

function NotePackageUpdate ($version, $verfile, $name, $size) {
    if ("$debug" -ne "true") {
        $version | Out-File $(Join-Path "${datapath}" "${verfile}") -NoNewline
    }
    if ($null -ne $size) {
        Write-Host "`"$name`" updated to `"$version`" [Size: $size]"
        SendPushover "Package Updated" "$name updated to $version [$size]"
    }
    else {
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
    if ($version -match "[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:\.[0-9]+? | \-[a-z]+[0-9]+)?") {
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
    if (-not $AKEY -or -not $UKEY) {
        Write-Host "Pushover Ignored: No AKEY or UKEY provided"
    }
    else {
        Send-Pushover -Token $AKEY -User $UKEY -MessageTitle $title -Message $message
    }
}

function DebugOut ($message) {
    if ("$debug" -eq "true") {
        Write-Host $message -ForegroundColor Red
    }
}

function ProcessChangelog ($data, $respnl, $spacing) {

    $nl=""
    if ($respnl -eq $true) {
        $nl="`r`n"
        DebugOut "Respect Newlines"

        $data = $data -replace "`r", ""
        $data = $data -replace "`n", ""    
    }

    if ($spacing -eq $true) {
        $data = $data -replace "\ \ +", " "
    }

    $data = $data -Replace '(?ms)<a.*?href="(.*?)".*?>(.*?)</a>', '[$2]($1)'  #Create a markdown link
    $data = $data -Replace "</li>", "" #Remove closing li tag
    $data = $data -Replace "<li>", "*" #Convert to *
    $data = $data -replace "&#8226;", "*" #Convert to *
            $data = $data -replace "<b>-</b>", "*" #Convert to *
            $data = $data -replace "&bull;", "*" #Convert to *
            $data = $data -replace "<br />", "$nl" #Remove line break tag
            $data = $data -replace "<br/>", "$nl" #Remove line break tag
            $data = $data -replace "<br>", $nl #Remove line break tag
            $data = $data -replace "</p>", "" #Remove closing p tag
            $data = $data -replace "<ul>", "" #Remove ul tag
            $data = $data -replace "</ul>", "" #Remove ul tag
            $data = $data -replace "</span>", "" #Remove span tag
            $data = $data -replace "<span.*?>", "" #Remove span tag
            $data = $data -replace "<div.*?>", "" #Remove div tag
            $data = $data -replace "</div>", "" #Remove div tag
            $data = $data -creplace '\s*\*\s*(\r?\n|$)', '' #Remove any empty lines on lines of their own
    
            $data = $data -Replace "<h1>", "# "
            $data = $data -Replace "<h2>", "## "
            $data = $data -Replace "</h1>", ""
            $data = $data -Replace "</h2>", ""

            $data = $data -creplace '(?m)^\*\S+', '*' #Make sure any lines starting with * has one whitespace character after
            $data = $data -replace "<p>", "`n" #Make sure any P tag creates a new line
            $data = (($data -Split "`n").Trim() -Join "`n") #Split all lines, trim them and then rejoin them

            $data = $data.Trim() # Trim spaces from stard and end of string

            DebugOut "Changelog Process:`n$data`n----------"
            return $data
        }
