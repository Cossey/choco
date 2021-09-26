#common functions for scripts

# Load in all environment variables
function LoadEnvVars () {
    Set-Variable -Name "DEBUG" -Value $env:DEBUG -Scope global
    
    if ($DEBUG -and $DEBUG -ne "false" -and $DEBUG -ne "true") {
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

#Load an evironment variable from the environment
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

function SetVersion ($ver) {
    if ($ver -match "^v.*") {
        $ver = $ver.substring(1)
    }
    $script:version = $ver
    if ($version -notmatch "[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:\.[0-9]+? | \-[a-z]+[0-9]+)?") {
        PackageError "Package: $packagename`nInvalid Version: $newversion"
        return $false
    }
    
    DebugOut "Old Version `"$lastversion`" | New Version `"$ver`""

    if ($lastversion -eq $ver) {
        Write-Host "No New Version"
        return $false
    }
    Write-Host "New Version: $ver"
    return $true
}

function SetRootURL ($url) {
    Write-Host "Root URL: $url"
    $script:rooturl = $url
}

function PrefixRootURL ($url) {
    if ($null -ne $url -and $url.StartsWith("/")) {
        $url = $rooturl + $url
    }
    return $url
}

function CompileTemplates ($32bit, $64bit, $releaseinfo, $extraparam) {
    $name = $templatename
    Write-Host "Building `"$name`" templates..."
    New-Item -ItemType Directory -Path $(Join-Path "$(TempFolder)" "tools") -ErrorAction Ignore | Out-Null

    Write-Host "Building nuspec template..."
    $nstemplate = Get-Content $(Join-Path "${templates}" "${name}.nuspec.template") -Raw

    $nstemplate = $nstemplate -replace "%tools%", "$(Join-Path "tools" "**")"
    $nstemplate = $nstemplate -replace "%year%", "$(Get-Date -format yyyy)"

    $nstemplate = $nstemplate -replace "%fileversion%", "$version"
    $nstemplate = $nstemplate -replace "%releaseinfo%", "$releaseinfo"
    
    $nstemplate = $nstemplate -replace "%filename32%", "$($32bit.filename)"
    $nstemplate = $nstemplate -replace "%hash32%", "$($32bit.hash)"
    $nstemplate = $nstemplate -replace "%url32%", "$($32bit.url)"

    $nstemplate = $nstemplate -replace "%filename64%", "$($64bit.filename)"
    $nstemplate = $nstemplate -replace "%hash64%", "$($64bit.hash)"
    $nstemplate = $nstemplate -replace "%url64%", "$($64bit.url)"

    $nstemplate = $nstemplate -replace "%extraparam%", "$extraparam"

    $nstemplate | Out-File $(Join-Path "$(TempFolder)" "${name}.nuspec")

    $files = Get-ChildItem -Path $templates -Filter "${name}_*"
    foreach ($file in $files) {
        if ($file.Name.EndsWith(".template")) {
            $outfilename = ($file.Name -replace ".{9}$" -replace ".*_")
            Write-Host "Compiling template '$outfilename'..."
            $templater = Get-Content $(Join-Path "${templates}" "$($file.Name)") -Raw

            $templater = $templater -replace "%fileversion%", "$version"
            $templater = $templater -replace "%releaseinfo%", "$releaseinfo"

            $templater = $templater -replace "%filename32%", "$($32bit.filename)"
            $templater = $templater -replace "%hash32%", "$($32bit.hash)"
            $templater = $templater -replace "%url32%", "$($32bit.url)"

            $templater = $templater -replace "%filename64%", "$($64bit.filename)"
            $templater = $templater -replace "%hash64%", "$($64bit.hash)"
            $templater = $templater -replace "%url64%", "$($64bit.url)"

            $templater = $templater -replace "%extraparam%", "$extraparam"
            
            $templater | Out-File $(Join-Path "$(TempFolder)" "tools" "${outfilename}")
        }
        else {
            $newfilename = $file.Name -replace ".*_"
            Write-Host "Copying file '$newfilename'"
            Copy-Item $(Join-Path "${templates}" "$($file.Name)") $(Join-Path "$(TempFolder)" "tools" "$newfilename")
        }
    }

    return $true
}

# Includes an EULA from a remote URL
# Parameters:
#     $url: The URL to the EULA
#     $regexparse: The regex to parse the EULA from a web page (if applicable)
# Returns:
#     $true if the EULA was successfully included, $false otherwise
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
        $licensefile = $url.Substring($url.LastIndexOf("/") + 1)
        DebugOut "EULA: $eula"
    }

    if ($eula.trim().length -eq 0) {
        PackageError "Failed to parse EULA from $url"
        return $false
    }

    $eulapath = Join-Path "$(TempFolder)" "tools" "$licensefile"
    Write-Host "Writing EULA from $url to $eulapath"
    $eula | Out-File -Path $eulapath
    return $true
}

# Includes files from a remote compressed archive
# Parameters:
#   $url: URL to the archive
#   $filetype: Type of archive (zip, 7z, etc) according to the 7z tool
# Returns:
#   $true if the archive was downloaded and extracted successfully
function IncludeZipFilesFromURL($url, $filetype) {
    $dlpath = Join-Path "$(TempFolder)" "tools"
    $out = CreateTempFileName

    Write-Host "Downloading compressed file at $url to $out..."
    Invoke-WebRequest -Uri $url -outfile $out

    $result = 7z x "$out" -o"$dlpath" -t"$filetype" -y -bd
    if ($LASTEXITCODE -ne "0") {
        PackageError "Error $LASTEXITCODE extracting $filetype file for $(TempFolder)"
        return $false
    }
    return $true
}

# Removes a single subfolder if it is not empty and there are no other folders in the parent folder
function RemoveSubfolder() {
    $tpath = Join-Path "$(TempFolder)" "tools"
    $filelist = Get-ChildItem -Path $tpath -File -ErrorAction Ignore
    $folderlist = Get-ChildItem -Path $tpath -Directory -ErrorAction Ignore

    if ($filelist.Length -eq 0 -and $folderlist.Length -eq 1) {
        Write-Host "Shifting Files..."
        Move-Item -Path $(Join-Path ${folderlist} "*") -Destination $tpath -Force -ErrorAction Ignore
        Remove-Item -Path ${folderlist} -ErrorAction Ignore
    }
}

# Downloads an installer from a remote URL and saves it to the specified folder
# Creates a .ignore file to stop the installer from being shimmed
# Parameters:
#     $url: The URL to the file
#     $filename: The name of the file to save
# Returns:
#     The filesize in bytes of the file
function DownloadInstallerFile($url, $filename) {
    if ($null -eq $filename) {
        $filename = $url.Substring($url.LastIndexOf("/") + 1)
    }
    $dlpath = Join-Path "$(TempFolder)" "tools" "$filename"
    $result = DownloadFile $url $dlpath

    Write-Host "Create ignore file for $dlpath"
    New-Item "${dlpath}.ignore" -type file -force | Out-Null

    return $result
}

function DownloadRemoteFile($url, $filename) {
    if ($null -eq $filename) {
        $filename = $url.Substring($url.LastIndexOf("/") + 1)
    }
    $dlpath = Join-Path "$(TempFolder)" "tools" "$filename"
    $result = DownloadFile $url $dlpath

    return $result
}

# Downloads a file from the remote URL and saves it to the specified folder
# Parameters:
#     $url: The URL to the file
#     $fullpath: The full file path to save the file to
# Returns:
#     The hash and filesize in bytes of the file
function DownloadFile($url, $fullpath) {
    $parent = Split-Path $fullpath -Parent
    New-Item -ItemType Directory -Path $parent -ErrorAction Ignore | Out-Null

    Write-Host "Download file at $url to $fullpath..."
    Invoke-WebRequest -Uri $url -outfile $fullpath

    $ret = "" | Select-Object -Property hash, size, url, filename
    $ret.hash = (Get-FileHash $fullpath).Hash
    $ret.size = (Get-Item $fullpath).Length
    $ret.url = $url
    $ret.filename = Split-Path $fullpath -leaf

    DebugOut "File Size `"$($ret.size)`" Hash `"$($ret.hash)`""
    
    return $ret
}

# Loads a list of links from a URL or WebRequest object
# Parameters:
#     $webrequest: Either a URL or webrequest
#     $filterlinks: The regex to parse the links from the web request
#     $addlink: Adds an additional link to the list
# Returns:
#     $true if there are links (excluding link from $addlink), false otherwise
function LinkList($webrequest, $filterlinks, $addlink) {
    $script:linklist = ""
    if ($webrequest.GetType().Name -eq "String") {
        $webrequest = Invoke-WebRequest -Uri $webrequest
    }
    $ret = $webrequest.Links | Select-Object -ExpandProperty href 

    if ($null -ne $filterlinks) {
        $ret = $ret | Where-Object { $_ -match "$filterlinks" }
    }

    if ($ret.length -eq 0) {
        PackageError "No links found"
        return $false
    }
    else {
        if ($null -ne $addlink) {
            $ret += $addlink
        }
        DebugOut "LinkList: $($ret)"
        $script:linklist = $ret
        return $true
    }
}

# Fetches a link from the link list. 
# Note: If the filter matches multiple results, only the first one will be returned.
# Parameters:
#     $filter: An index or regex of link to fetch
# Returns:
#     The link
function GetLinkList($filter) {
    if ($filter.GetType().Name -eq "Int32") {
        $url = $linklist[$filter]
    }
    else {
        $url = $linklist | Where-Object { $_ -match $filter } | Select-Object -First 1
    }
    $fulllink = PrefixRootURL $url
    DebugOut "GetLinkList: $($fulllink)"
    return PrefixRootURL $fulllink
}

function RemoteFileDetails($url) {
    $location = CreateTempFileName
    $details = DownloadFile $url $location

    if ("$debug" -ne "true") {
        Remove-Item -path $location
        Write-Host "Removed temporary file `"$location`""
    }

    return $details
}

# Get the release info from a webpage.
# Parameters:
#     $url: The URL to the webpage
#     $filter: A regex to filter the links to the release page.
#              Must use named groups info and date for release date.
#     $processchangelog: A boolean to indicate if the changelog should be processed
# Returns:
#     The processed release info
function ObtainReleaseInfo($url, $filter, $processchangelog) {
    $releaseinfo = Invoke-WebRequest -Uri $url
    $processed = [regex]::match($releaseinfo.Content, $filter, [Text.RegularExpressions.RegexOptions]::Singleline)

    $releaseinfo = $processed.Groups['info'].Value
    $releasedate = $processed.Groups['date'].Value

    return ProcessReleaseInfo $releaseinfo $releasedate $processchangelog
}

# Process release info from variables.
# Parameters:
#     $releaseinfo: The release info
#     $releasedate: The release date
#     $processchangelog: A boolean to indicate if the changelog should be processed
# Returns:
#     The processed release info
function ProcessReleaseInfo($releaseinfo, $releasedate, $processchangelog) {
    if ($processchangelog) {
        $releaseinfo = ProcessChangelog $releaseinfo
    }

    if ($null -ne $releasedate) {
        $releaseinfo = @"
Released $releasedate

$releaseinfo
"@
    }

    return $releaseinfo
}

function RemoteFileZipDetails($url) {
    $location = CreateTempFileName
    $details = DownloadFile $url $location

    $zip = [IO.Compression.ZipFile]::OpenRead($location)
    $filelist = $zip.Entries
    $zip.Dispose()
    DebugOut "File Count in Zip $($filelist.Count)"

    $ret = "" | Select-Object -Property file, contents

    $ret.file = $details
    $ret.contents = $filelist

    if ("$debug" -ne "true") {
        Remove-Item -path $location
        Write-Host "Removed temporary file `"$location`""
    }

    return $ret
}

# Gets a download URL for a release on GitHub
# Parameters:
#     $repo: The GitHub repository
#     $filter: The filter to match for the download file
# Returns:
#     Object containing the download url, file size and version tag
function GitHubRelease($repo, $filter) {
    $url = "https://api.github.com/repos/$repo/releases/latest"
    $releaseinfo = Invoke-WebRequest $url
    $json = ConvertFrom-Json $releaseinfo.Content

    $ret = "" | Select-Object -Property version, url, size
    $ret.version = $json.tag_name
    foreach ($file in $json.assets) {
        if ($file.browser_download_url -match "$filter") {
            $ret.url = $file.browser_download_url
            $ret.size = $file.size
        }
    }
    return $ret
}

# Gets json from a remote URL
# Parameters:
#     $url: The URL
# Returns:
#     The JSON object
function JsonUri($uri) {
    $json = Invoke-WebRequest -Uri $uri -Method Get -ContentType "application/json"
    return ConvertFrom-Json $json.Content
}

function CreateTempFileName() {
    $randomstring = ( -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ }))
    New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
    return $(Join-Path "${temp}" "${randomstring}")
}

function ExtractZipFromURL ($url) {
    $out = CreateTempFileName
    try {
        New-Item -ItemType Directory -Path "$temp" -ErrorAction Ignore | Out-Null
        Write-Host "Downloading File to `"$out`"..."
        Invoke-WebRequest -Uri $url -outfile $out
        $size = (Get-Item $out).length
        Write-Host "Downloaded File - $size bytes, Extracting file..."
        [System.IO.Compression.ZipFile]::ExtractToDirectory($out, "$(TempFolder)/tools")
        Write-Host "Extraction complete"
        
        Write-Host "Removed temporary file `"$out`""
        return $true
    }
    catch {
        Write-Host "Error Extracting Zip From `"$url`""
        PackageError "Package: $(TempFolder)`nError Extracting from URL: $url"
        return $false
    }
    finally {
        Remove-Item -Path $out
    }
}

# Pushes the package to chocolatey community repository
# Parameters:
#     $attempt: The attempt number
#     $backoff: The backoff time in seconds
# Returns:
#     $true if successful, $false failed to push after attempts
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
            PackageError "Failed to push package $packagename after $MAX_PUSH_ATTEMPTS attempts"
            return $false
        }
        else {
            Write-Host "Retrying in $($backoff / 60) minutes..."
            Start-Sleep -Seconds $backoff
            return DoPush $attempt $backoff
        }
    } 
    return $true
}

function TempCleanup() {
    $allfiles = Join-Path "$temp" "*"
    Write-Host "Cleaning up any leftover temporary files..."
    Remove-Item -Path "$allfiles" -Recurse -Force -ErrorAction SilentlyContinue
}

# Packs the package and cleans the temporary folder
# Returns:
#     $true if successful, $false if failed
function PackAndClean () {
    Set-Location -Path "$(TempFolder)"
    Write-Host "Packing `"$(TempFolder)`"..."
    $result = (choco pack)
    if ($LASTEXITCODE -ne "0") {
        Write-Host "Pack return exit code $LASTEXITCODE at $(Get-Date)`n-----------`n$result`n-----------"
        if ("$debug" -ne "true") {
            PackageError "Package $(TempFolder) Pack Error`n$result"
            Remove-Item -Path "$(TempFolder)" -Recurse -Force
        }
        return $false
    }
    if ("$debug" -ne "true") {
        if (DoPush 0) {
            Write-Host "Push successfull"
        }
        else {
            if ("$debug" -ne "true") {
                Write-Host "Cleaning..."
                Remove-Item -Path "$(TempFolder)" -Recurse -Force
            }
            return $false
        }
    }
    Set-Location -Path $temp
    if ("$debug" -ne "true") {
        Write-Host "Cleaning..."
        Remove-Item -Path "$(TempFolder)" -Recurse -Force
    }
    return $true
}

function ItemEmpty ($obj, $packagename, $objname) {
    if ($obj -eq "") {
        PackageError "Empty Var: $objname"
        return $true
    } 
    return $false
}

function InitPackage ($packagename) {
    $script:templatename = $packagename
    Write-Host "[$packagename]" -ForegroundColor Yellow
    $script:lastversion = Get-Content -Path $(VersionFile) -Raw -ErrorAction Ignore
    if ($lastversion -eq "~") {
        Write-Host "Skip updating package"
        return $false
    }
    return $true
}

function TempFolder () {
    Join-Path $temp $templatename
}

function PackageUpdated ($size) {
    if ("$debug" -ne "true") {
        $version | Out-File $(VersionFile) -NoNewline
    }
    if ($null -ne $size) {
        Write-Host "`"$templatename`" updated to `"$version`" [Size: $(GetFileSize $size)]"
        SendPushover "Package Updated" "$templatename updated to $version [$(GetFileSize $size)]"
    }
    else {
        Write-Host "`"$templatename`" updated to `"$version`""
        SendPushover "Package Updated" "$templatename updated to $version"
    }
}

function VersionFile () {
    $verfile = $(Join-Path "${datapath}" "${templatename}.ver")
    DebugOut "Version file: $verfile"
    return $verfile
}

# Converts files from bytes to megabytes
# Parameters:
#     $bytesize: The size in bytes
# Returns:
#     The size in megabytes
function GetFileSize ($bytesize) {
    return (($bytesize / 1MB).ToString("0.00") + "MB")
}

function PackageError($message) {
    Write-Host "ERROR: $message" -ForegroundColor Red
    SendPushover "Package Error: $($packagename)" "$message"
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

# Processes any change log notes or EULAs from web page scrapes
# Parameters:
#     $data: The data to process
#     $respnl: Respect new lines
#     $spacing: Data has excessive spacing
# Returns:
#     The processed data
function ProcessChangelog ($data, $respnl, $spacing) {

    $nl = ""
    if ($respnl -eq $true) {
        $nl = "`r`n"
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
