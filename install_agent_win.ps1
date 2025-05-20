# === Configuration ===
$ZabbixServer = "monitor.server-shop.ua"
$AgentVersion = "7.2.6"
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$TempDir = "$env:TEMP\zabbix_agent"
$ZipPath = "$env:TEMP\zabbix_agent.zip"
$AgentExe = "$TempDir\bin\zabbix_agentd.exe"
$ConfPath = "$TempDir\conf\zabbix_agentd.conf"

# === Get system hostname
try {
    $Hostname = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($Hostname)) {
        $Hostname = "client-" + [int](Get-Date -UFormat %s)
        Write-Host "[WARN] Hostname not found. Generated: $Hostname"
    } else {
        Write-Host "[INFO] Using hostname: $Hostname"
    }
} catch {
    $Hostname = "client-" + [int](Get-Date -UFormat %s)
    Write-Host "[WARN] Error while retrieving hostname. Using: $Hostname"
}

# === Ensure TLS 1.2 for HTTPS
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    Write-Host "[WARN] TLS 1.2 not supported"
}

# === Check for existing Zabbix Agent service
$Service = Get-Service -Name "Zabbix Agent" -ErrorAction SilentlyContinue
if ($Service) {
    Write-Host "[INFO] Zabbix Agent service is installed."
    $stop = Read-Host "Service is running — stop it? [Y/n]"
    if ($stop -eq "" -or $stop -match "^[Yy]") {
        Stop-Service -Name "Zabbix Agent" -Force
        Start-Sleep -Seconds 2
    } else {
        Write-Host "[INFO] Skipping service stop."
    }
}

# === Check for installed agent version
$InstalledPath = "C:\Program Files\Zabbix Agent\zabbix_agentd.exe"
if (Test-Path $InstalledPath) {
    try {
        $output = & $InstalledPath --version 2>$null
        $line = $output | Where-Object { $_ -match "Zabbix Agent" }
        if ($line) {
            $tokens = $line -split " "
            if ($tokens.Count -ge 3) {
                $currentVersion = $tokens[2]
                Write-Host "[INFO] Installed agent version: $currentVersion"
                $replace = Read-Host "Replace with version $AgentVersion? [Y/n]"
                if (-not ($replace -eq "" -or $replace -match "^[Yy]")) {
                    Write-Host "[INFO] Skipping installation."
                    exit
                }
            } else {
                Write-Host "[WARN] Could not parse agent version — skipping version check."
            }
        } else {
            Write-Host "[WARN] Version string not found in agent output."
        }
    } catch {
        Write-Host "[WARN] Error checking installed version — skipping check."
    }
}

# === Download agent zip
$DownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/7.2/$AgentVersion/zabbix_agent-$AgentVersion-windows-$Arch-openssl.zip"
Write-Host "[INFO] Downloading Zabbix Agent $AgentVersion ($Arch)..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# === Extract files
Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

# === Confirm config overwrite
if (Test-Path $ConfPath) {
    $overwrite = Read-Host "Config file found — overwrite it? [Y/n]"
    if ($overwrite -eq "" -or $overwrite -match "^[Yy]") {
        Write-Host "[INFO] Writing configuration..."
        (Get-Content $ConfPath) -replace '^Server=.*', "Server=$ZabbixServer" `
                                -replace '^ServerActive=.*', "ServerActive=$ZabbixServer" `
                                -replace '^Hostname=.*', "Hostname=$Hostname" `
                                | Set-Content $ConfPath
    } else {
        Write-Host "[INFO] Keeping existing configuration."
    }
}

# === (Re)Install service
Write-Host "[INFO] Installing Zabbix Agent service..."
& "$AgentExe" --config "$ConfPath" --install

# === Start service
Start-Service -Name "Zabbix Agent"
Set-Service -Name "Zabbix Agent" -StartupType Automatic

# === Done
Write-Host ""
Write-Host "[SUCCESS] Zabbix Agent installed and running"
Write-Host "[INFO] Hostname: $Hostname"
Write-Host "[INFO] Zabbix Server: $ZabbixServer"