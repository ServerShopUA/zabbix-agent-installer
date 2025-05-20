# === Configuration ===
$ZabbixServer = "monitor.server-shop.ua"
$AgentMajor = "7.2"
$PlatformArch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "i386" }
$DownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/$AgentMajor/latest/zabbix_agent2-$AgentMajor-latest-windows-$PlatformArch-openssl-static.zip"
$TempDir = "$env:TEMP\zabbix_agent"
$ZipPath = "$env:TEMP\zabbix_agent.zip"
$AgentExe = "$TempDir\bin\zabbix_agentd.exe"
$ConfPath = "C:\zabbix\zabbix_agentd.conf"
$InstalledPath = "C:\zabbix\zabbix_agentd.exe"

# === Get hostname
$Hostname = $env:COMPUTERNAME
if ([string]::IsNullOrWhiteSpace($Hostname)) {
    $Hostname = "client-" + [int](Get-Date -UFormat %s)
}
Clear-Host
Write-Host "[INFO] Using hostname: $Hostname"

# === Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# === Stop service if running
$Service = Get-Service -Name "Zabbix Agent" -ErrorAction SilentlyContinue
if ($Service) {
	Clear-Host
    Write-Host "[INFO] Zabbix Agent service is installed."
    $stop = Read-Host "Service is running - stop it? [Y/n]"
    if ($stop -eq "" -or $stop -match "^[Yy]") {
        Stop-Service -Name "Zabbix Agent" -Force
        Start-Sleep -Seconds 2
    } else {
        Write-Host "[INFO] Skipping service stop."
    }
}

# === Check if agent is installed
if (Test-Path $InstalledPath) {
	Clear-Host
    Write-Host "[INFO] Zabbix Agent is already installed."
    $replace = Read-Host "Replace with new version? [Y/n]"
    if (-not ($replace -eq "" -or $replace -match "^[Yy]")) {
        Write-Host "[INFO] Skipping installation."
        exit
    }
}

# === Download
Clear-Host
Write-Host "[INFO] Downloading Zabbix Agent ($Arch)..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# === Extract
Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

# === Configure
if (Test-Path $ConfPath) {
    $overwrite = Read-Host "Config found - overwrite it? [Y/n]"
    if ($overwrite -eq "" -or $overwrite -match "^[Yy]") {
        (Get-Content $ConfPath) -replace '^Server=.*', "Server=$ZabbixServer" `
                                -replace '^ServerActive=.*', "ServerActive=$ZabbixServer" `
                                -replace '^Hostname=.*', "Hostname=$Hostname" `
                                | Set-Content $ConfPath
    } else {
        Write-Host "[INFO] Keeping existing config."
    }
}

# === Install agent
if (!(Test-Path $AgentExe)) {
    Write-Host "[ERROR] Agent binary not found at $AgentExe"
    exit 1
}

Write-Host "[INFO] Installing Zabbix Agent service..."
& "$AgentExe" --config "$ConfPath" --install
Start-Service -Name "Zabbix Agent"
Set-Service -Name "Zabbix Agent" -StartupType Automatic

# === Done
Write-Host ""
Write-Host "[SUCCESS] Zabbix Agent installed and running"
Write-Host "[INFO] Hostname: $Hostname"
Write-Host "[INFO] Zabbix Server: $ZabbixServer"