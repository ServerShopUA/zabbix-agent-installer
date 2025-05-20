# === Config ===
$ZabbixServer = "zabbix.server-shop.ua"
$AgentVersion = "7.2.6"
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$TempDir = "$env:TEMP\zabbix_agent"
$ZipPath = "$env:TEMP\zabbix_agent.zip"

# === Get hostname ===
try {
    $Hostname = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($Hostname)) {
        $Hostname = "client-" + [int](Get-Date -UFormat %s)
        Write-Host "[WARN] Cannot get system hostname. Generated: $Hostname"
    } else {
        Write-Host "[INFO] Using hostname: $Hostname"
    }
} catch {
    $Hostname = "client-" + [int](Get-Date -UFormat %s)
    Write-Host "[WARN] Error getting hostname. Using: $Hostname"
}

# === Download Zabbix Agent ===
$DownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/7.2/$AgentVersion/zabbix_agent-$AgentVersion-windows-$Arch-openssl.zip"
Write-Host "[INFO] Downloading Zabbix Agent $AgentVersion ($Arch)..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# === Extract ===
Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
$ConfPath = "$TempDir\conf\zabbix_agentd.conf"

# === Configure agent ===
Write-Host "[INFO] Configuring agent..."
(Get-Content $ConfPath) -replace '^Server=.*', "Server=$ZabbixServer" `
                        -replace '^ServerActive=.*', "ServerActive=$ZabbixServer" `
                        -replace '^Hostname=.*', "Hostname=$Hostname" `
                        | Set-Content $ConfPath

# === Install and start service ===
& "$TempDir\bin\zabbix_agentd.exe" --config "$ConfPath" --install
Start-Service -Name "Zabbix Agent"
Set-Service -Name "Zabbix Agent" -StartupType Automatic

# === Done ===
Write-Host ""
Write-Host "[SUCCESS] Zabbix Agent installed successfully"
Write-Host "[INFO] Hostname: $Hostname"
Write-Host "[INFO] Zabbix Server: $ZabbixServer"