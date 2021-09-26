if (InitPackage("proxallium")) {
    $dlinfo = GitHubRelease "DcodingTheWeb/ProxAllium" ".*\.7z$"

    if (SetVersion($dlinfo.version)) {
        $installer32 = DownloadRemoteFile $dlinfo.url

        if (IncludeEULA "https://raw.githubusercontent.com/DcodingTheWeb/ProxAllium/master/LICENSE") {

            if (CompileTemplates $installer32) {
                if (PackAndClean) { 
                    PackageUpdated $dlinfo.size
                }
            }
        }
    }
}
