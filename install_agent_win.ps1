# === Налаштування ===
$ZabbixServer = "zabbix.server-shop.ua"
$AgentVersion = "7.2.6"
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$TempDir = "$env:TEMP\zabbix_agent"
$ZipPath = "$env:TEMP\zabbix_agent.zip"

# === Отримуємо hostname
try {
    $Hostname = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($Hostname)) {
        $Hostname = "client-" + [int](Get-Date -UFormat %s)
        Write-Host "[WARN] Не вдалося отримати hostname. Використовується згенерований: $Hostname"
    } else {
        Write-Host "[INFO] Використовується hostname: $Hostname"
    }
} catch {
    $Hostname = "client-" + [int](Get-Date -UFormat %s)
    Write-Host "[WARN] Помилка при отриманні hostname. Використовується: $Hostname"
}

# === Завантаження агента
$DownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/7.2/$AgentVersion/zabbix_agent-$AgentVersion-windows-$Arch-openssl.zip"
Write-Host "⬇️ Завантаження Zabbix Agent $AgentVersion ($Arch)..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# === Розпаковка
Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
$ConfPath = "$TempDir\conf\zabbix_agentd.conf"

# === Налаштування конфігу
Write-Host "⚙️ Налаштування конфігурації..."
(Get-Content $ConfPath) -replace '^Server=.*', "Server=$ZabbixServer" `
                        -replace '^ServerActive=.*', "ServerActive=$ZabbixServer" `
                        -replace '^Hostname=.*', "Hostname=$Hostname" `
                        | Set-Content $ConfPath

# === Встановлення служби
& "$TempDir\bin\zabbix_agentd.exe" --config "$ConfPath" --install
Start-Service -Name "Zabbix Agent"
Set-Service -Name "Zabbix Agent" -StartupType Automatic

Write-Host ""
Write-Host "✅ Агента встановлено. Hostname: $Hostname"
Write-Host "➡️ Zabbix Server: $ZabbixServer"