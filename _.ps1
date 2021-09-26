#Example package builder file

#Set the root URL (some web page links do not include the root url)
SetRootURL "https://www.webpage.com"

#You can affix the root url onto urls starting with "/""
PrefixRootUrl "/webpage/link.html"

#Gets a list of links on the webpage (you can also add an additional link to the array)
#The regex filter will select only links that match the regex (use ".*\.exe$" for exe links only)
#You can use GetLinkList to get a list of links from this array.
#Returns false if there are no links after filter (does not count the EXTRALINK)
if (!(Linklist "URL" "REGEX" "EXTRALINK")) { return }

#Scrape the changelog from a url. Use the Regex with the capture group of date and info to capture 
#the date and the changelog data. The processchangelog sends the changelog through the markup processor.
$releaseinfo = ObtainReleaseInfo "URL" "REGEX" "PROCESSCHANGELOG?"

#Initialise package system. The package name is the same as the file prefixes in the templates folder
if (InitPackage("PACKAGENAME")) {

    #Checks the version of the package. If the version is not the same as the version recorded in the ver file
    #Then it will continue.
    if (SetVersion "VERSIONNO") {
        #Download the installer and save it into the package. REQUIRES PERMISSION FROM PUBLISHER OR COMPATBLE LICENCE
        $installer32 = DownloadInstallerFile "URL"

        #Get the Remote file details for when a installer will be shimmed (not included in package due to distribution restrictions)
        $installer32 = RemoteFileDetails "URL"

        #Include an EULA in the package (LICENCE.md/LICENCE.txt). Required for including executables in the package (not shimming).
        #The regex is used to extra the EULA when scraping a web page
        if (IncludeEULA "EULAURL" "REGEX") {

            #Compile the templates and copy the files in the templates folder
            #Pass through the installer 32 and 64 bit information (url, filename, size and hashes) and the release info
            #You can also pass through an additional field with the $extraparam parameter.
            if (CompileTemplates $installer32 $installer64 $releaseinfo $extraparam) {
                #Choco pack, push and then cleanup temp files and folders
                if (PackAndCleanup) {
                    #Update package version file and send push notification
                    PackageUpdated
                }
            }
        }
    }
}