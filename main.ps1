$datapath = "/data"
#$datapath = "./"

while ($true) {
    Write-Host "-----------------------------"
    Write-Host "Running at $(Get-Date)"
    Invoke-Expression -Command "${PSScriptRoot}/burnaware.ps1 ${datapath}/burnaware.ver"
    Invoke-Expression -Command "${PSScriptRoot}/acardaoutbound.ps1 ${datapath}/aos.ver ${datapath}/aot.ver"
    Start-Sleep -Seconds ([int]$Env:DELAY * 60)
}
