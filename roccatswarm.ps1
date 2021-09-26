if (InitPackage("roccatswarm")) {
    $api = JsonUri("https://api.roccat-neon.com/device/Support/Downloads/en/202/v2")

    if (SetVersion($api.download.version)) {
        
        $release = "Released $($api.download.release)"
        $changelogjson = $api.download.changelog.'ROCCAT® Swarm'[0].changelog;
        $changelogdata = Join-String -InputObject $changelogjson -Separator "`r`n"

        $releaseinfo = ProcessReleaseInfo $changelogdata $release $true

        $details = RemoteFileZipDetails $api.download.url

        $installfile = $details.contents | Where-Object { $_.FullName -like '*.exe' } | Select-Object -First 1
        Write-Host "Install file: $installfile"

        if (CompileTemplates $details.file $null $releaseinfo $installfile) {
            if (PackAndClean) {
                PackageUpdated
            }
        }
    }
}
