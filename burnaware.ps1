#Burnaware
SetRootURL "https://www.burnaware.com"
$currentversionurl = PrefixRootURL "/download.html"
$whatsnewurl = PrefixRootURL "/whats-new.html"
$eulaurl = PrefixRootURL "/eula.html"
$eulafilter = "<div class=`"container mt-5`">(.*?)</div>"

$currentversion = Invoke-WebRequest -Uri $currentversionurl
$onlineversion = [regex]::match($currentversion.Content, "[Vv]ersion ([0-9]+\.[0-9]*)", [Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$freeurl = "/downloads/burnaware_cfree_${onlineversion}.exe"

if (!(Linklist $currentversion ".*\.exe$" $freeurl)) { return }

$releaseinfo = ObtainReleaseInfo $whatsnewurl "Released (?<date>.*)</small>.*?<p.*?>(?<info>.*?)</p>" $true
if (ItemEmpty $releaseinfo "Burnaware" "Release Info") {return}

if (InitPackage("burnawarefree")) {
    if (SetVersion ($onlineversion)) {
        $installer32 = DownloadInstallerFile (GetLinkList ".*cfree.*")

        if (IncludeEULA $eulaurl $eulafilter) {
            if (CompileTemplates $installer32 $null $releaseinfo) {
                if (PackAndClean) {
                    PackageUpdated
                }
            }
        }
    }
}

if (InitPackage("burnawarepremium")) {
    if (SetVersion ($onlineversion)) {
        $installer32 = DownloadInstallerFile (GetLinkList ".*premium(?!.*x64).*")
        $installer64 = DownloadInstallerFile (GetLinkList ".*premium.*x64.*")

        if (IncludeEULA $eulaurl $eulafilter) {
            if (CompileTemplates $installer32 $installer64 $releaseinfo) {
                if (PackAndClean) {
                    PackageUpdated
                }
            }
        }
    }
}

if (InitPackage("burnawarepro")) {
    if (SetVersion ($onlineversion)) {
        $installer32 = DownloadInstallerFile (GetLinkList ".*pro(?!.*x64).*")
        $installer64 = DownloadInstallerFile (GetLinkList ".*pro.*x64.*")

        if (IncludeEULA $eulaurl $eulafilter) {
            if (CompileTemplates $installer32 $installer64 $releaseinfo) {
                if (PackAndClean) {
                    PackageUpdated
                }
            }
        }
    }
}
