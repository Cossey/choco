if (InitPackage("siril")) {
    SetRootURL "https://free-astro.org"
    $releasesurl = PrefixRootURL "/index.php?title=Siril:releases"
    
    if (LinkList $releasesurl "Siril:[0-9.]+") {
        $releaseurl = GetLinkList 0
    
        if (SetVersion([regex]::match($releaseurl, "Siril:([0-9.]*)").Groups[1].Value)) {
            $releaseinfo = ObtainReleaseInfo $releaseurl "<b>Release date: (?<date>.*?)</b>.*What?'s new.*?</h2>(?<info>.*?)(<!--|</div>)" $true

            if (LinkList $releaseurl) {
                $dlpage = GetLinkList ".*/download/.*"

                if (LinkList $dlpage) {
                    $windowsdownload = GetLinkList ".*\.exe$"

                    $installer64 = DownloadInstallerFile $windowsdownload 
                    if (IncludeEULA "https://gitlab.com/free-astro/siril/-/raw/master/LICENSE.md") {
                        if (CompileTemplates $null $installer64 $releaseinfo) {
                            if (PackAndClean) {
                                PackageUpdated $size
                            }
                        }
                    }
                }
            }
        }
    }
}
