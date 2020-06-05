#Example package builder file

PackageName "Package Name"

#Common Script Vars
$templatename = "packageid"
$tempfolder = "$temp/$templatename/"
$verfile = "$templatename.ver"
$oldversion = GetLastVersion $verfile

if (CheckSkip $oldversion) {return}

#Get version here

if (VersionNotValid $version $templatename) {return}

if (VersionNotNew $oldversion $version) {return}


#Get changelog and process. Below will remove any formatting from webpages

$changelog = ProcessChangelog $changelog

#Download files for inclusion or download file to check hash and filesize

$fileinfo = HashAndSizeFromFileURL $downloadurl
$filehash = $fileinfo[0]
$filesize = $fileinfo[1]

#Build templates from templates/ folder
#Any file starting with "packageid_" will be copied to tools/ folder and have the prefix removed
#Any files ending in ".template" will run through the templating system and be output with the .template postfix removed
BuildTemplate $tempfolder $templatename $filehash $downloadurl $version $changelog

#Pack into nupkg and upload to community repo
if (!(PackAndClean $tempfolder)) {return}

#Update version file and send pushover notification
NotePackageUpdate $version $verfile $templatename (GetFileSize $filesize)
