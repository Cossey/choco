if (InitPackage("siril")) {
    SetRootURL "https://siril.org"
    $releasesurl = PrefixRootURL "/download/"
    
    if (LinkList $releasesurl ".*-siril-.*") {
        $releaseurl = GetLinkList 0
    
        if (SetVersion([regex]::match($releaseurl, ".*-siril-(.*?)/").Groups[1].Value)) {            
            $releaseinfo = ObtainReleaseInfo $releaseurl ".*?released on\s+(?<date>.*?)\..*id=`"whats-new`".*?</h[1-3]>(?<info>.*?)<h[1-3]" $true

            if (LinkList $releaseurl) {
                $windowsdownload = GetLinkList ".*\.exe$"

                 
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
