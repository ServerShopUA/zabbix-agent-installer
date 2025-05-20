# === Налаштування ===
$ZabbixServer = "zabbix.server-shop.ua"
$AgentVersion = "7.2.6"
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$TempDir = "$env:TEMP\zabbix_agent"
$ZipPath = "$env:TEMP\zabbix_agent.zip"

# === Введення hostname ===
$Hostname = Read-Host "Введіть бажаний Hostname для Zabbix"

if ([string]::IsNullOrWhiteSpace($Hostname)) {
    Write-Host "[ERROR] Hostname не може бути порожнім" -ForegroundColor Red
    exit
}

# === Завантаження ===
$DownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/7.2/$AgentVersion/zabbix_agent-$AgentVersion-windows-$Arch-openssl.zip"
Write-Host "🔽 Завантаження Zabbix Agent $AgentVersion ($Arch)..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# === Розпаковка ===
Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
$ConfPath = "$TempDir\conf\zabbix_agentd.conf"

# === Налаштування конфігу ===
Write-Host "⚙ Налаштування конфігурації..."
(Get-Content $ConfPath) -replace '^Server=.*', "Server=$ZabbixServer" `
                        -replace '^ServerActive=.*', "ServerActive=$ZabbixServer" `
                        -replace '^Hostname=.*', "Hostname=$Hostname" `
                        | Set-Content $ConfPath

# === Встановлення служби ===
& "$TempDir\bin\zabbix_agentd.exe" --config "$ConfPath" --install
Start-Service -Name "Zabbix Agent"
Set-Service -Name "Zabbix Agent" -StartupType Automatic

Write-Host "`n✅ Агент встановлено. Hostname: $Hostname" -ForegroundColor Green