# === Configuration ===
$ZabbixServer = "monitor.server-shop.ua"
$AgentMajor = "7.2"
$PlatformArch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "i386" }
$DownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/$AgentMajor/latest/zabbix_agent2-$AgentMajor-latest-windows-$PlatformArch-openssl-static.zip"
$TempDir = "$env:TEMP\zabbix_agent"
$ZipPath = "$env:TEMP\zabbix_agent.zip"
$InstallDir = "C:\zabbix"
$AgentExe = "C:\zabbix\bin\zabbix_agent2.exe"
$ConfPath = "C:\zabbix\conf\zabbix_agent2.conf"
$ServiceName = "Zabbix Agent 2"

# === Get hostname
$Hostname = $env:COMPUTERNAME
if ([string]::IsNullOrWhiteSpace($Hostname)) {
    $Hostname = "client-" + [int](Get-Date -UFormat %s)
}
Write-Host "[INFO] Using hostname: $Hostname"

# === Show current Zabbix services state ===
Write-Host "`n[INFO] Existing Zabbix services before installation:"
Get-Service | Where-Object { $_.DisplayName -like "Zabbix*" } | Select Name, DisplayName, Status | Format-Table | Out-Host

# === Check if Zabbix Agent 2 service exists
$svc = Get-Service -Name "Zabbix Agent 2" -ErrorAction SilentlyContinue
if ($svc) {
    $replace = Read-Host "Replace with new version? [Y/n]"
    if ($replace -eq "" -or $replace -match "^[Yy]") {
        try {
            if ($svc.Status -eq "Running") {
                Stop-Service -Name $ServiceName -Force
                Start-Sleep -Seconds 1
            }

            $PathRaw = (Get-WmiObject Win32_Service -Filter "Name='Zabbix Agent 2'").PathName
            $ExecutablePath = if ($PathRaw -match '^(\"?[^\" ]+\.exe)') { $matches[1].Trim('"') } else { $null }

            if ($ExecutablePath -and (Test-Path $ExecutablePath)) {
				$TempConf = "$env:TEMP\zabbix_agent2_empty.conf"
				if (!(Test-Path $TempConf)) {
					"" | Out-File -Encoding ASCII -FilePath $TempConf
				}
				& $ExecutablePath --uninstall -c $TempConf
				Write-Host "[INFO] Service uninstalled via agent executable with temporary config."
				Remove-Item $TempConf -Force
            } else {
                Write-Host "[WARN] Could not find executable or path invalid."
            }
        } catch {
            Write-Host "[WARN] Could not uninstall service: $($_.Exception.Message)"
        }
    } else {
        Write-Host "[INFO] Skipping installation."
        exit
    }
}

# === Force TLS 1.2 ===
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# === Download
Write-Host "[INFO] Downloading Zabbix Agent ($PlatformArch)..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# === Extract
if (Test-Path $InstallDir) {
    Remove-Item "$InstallDir\*" -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $InstallDir)


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
Start-Service -Name $ServiceName
Set-Service -Name $ServiceName -StartupType Automatic

# === Done
Write-Host ""
Write-Host "[SUCCESS] Zabbix Agent installed and running"
Write-Host "[INFO] Hostname: $Hostname"
Write-Host "[INFO] Zabbix Server: $ZabbixServer"

# === Show updated Zabbix services state ===
Write-Host "`n[INFO] Zabbix services after installation:"
Get-Service | Where-Object { $_.DisplayName -like "Zabbix*" } | Select Name, DisplayName, Status | Format-Table | Out-Host