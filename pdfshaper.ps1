#PDF Shaper

# Common Data
SetRootURL "https://www.pdfshaper.com"
$currentversionurl = PrefixRootURL "/download.html"
$whatsnewurl = PrefixRootURL "/release-notes.html"
$eulaurl = "https://www.pdfshaper.com/eula.html"
$eulafilter = "<p class=`"lead`">(.*?)</p>"

$currentversion = Invoke-WebRequest -Uri $currentversionurl
$onlineversion = [regex]::match($currentversion.Content, "[Vv]ersion ([0-9]+\.[0-9]*)", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$freeurl = "/downloads/pdfshaper_cfree_${onlineversion}.exe"

if (!(LinkList $currentversion ".*\.exe$" $freeurl)) { return }

$releaseinfo = ObtainReleaseInfo $whatsnewurl "<p class=`"text-muted`">Released (?<date>.*?)</p>(?<info>.*?)(?:<script async|<a href=\`"download.html\`")" $true
if (ItemEmpty $releaseinfo "PDF Shaper" "Release Info") { return }

# Pdf Shaper Packages
if (InitPackage("pdfshaperfree")) {
    if (SetVersion ($onlineversion)) {
        $installer32 = DownloadInstallerFile (GetLinkList(".*cfree.*"))
        
        if (IncludeEULA $eulaurl $eulafilter) {
            if (CompileTemplates $installer32 $null $releaseinfo) {
                if (PackAndClean) {
                    PackageUpdated
                }
            }
        }
    }
}

if (InitPackage("pdfshaperpro")) {
    if (SetVersion ($onlineversion)) {
        $installer32 = DownloadInstallerFile (GetLinkList(".*pro(?!.*x64).*"))
        $installer64 = DownloadInstallerFile (GetLinkList(".*pro.*x64.*"))
        
        if (IncludeEULA $eulaurl $eulafilter) {
            if (CompileTemplates $installer32 $installer64 $releaseinfo) {
                if (PackAndClean) {
                    PackageUpdated
                }
            }
        }
    }
}

if (InitPackage("pdfshaperpremium")) {
    if (SetVersion ($onlineversion)) {
        $installer32 = DownloadInstallerFile (GetLinkList(".*premium(?!.*x64).*"))
        $installer64 = DownloadInstallerFile (GetLinkList(".*premium.*x64.*"))
        
        if (IncludeEULA $eulaurl $eulafilter) {
            if (CompileTemplates $installer32 $installer64 $releaseinfo) {
                if (PackAndClean) {
                    PackageUpdated
                }
            }
        }
    }
}
