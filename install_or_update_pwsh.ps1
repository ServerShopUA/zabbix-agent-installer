# Check if PowerShell 7+ is installed
$pwshPath = "$env:ProgramFiles\PowerShell\7\pwsh.exe"

if (Test-Path $pwshPath) {
    $version = & "$pwshPath" -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
    Write-Host "[INFO] PowerShell 7 already installed: v$version"
    exit
}

# Download latest stable PowerShell MSI
$latestVersion = "7.4.2"
$installerUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$latestVersion/PowerShell-$latestVersion-win-x64.msi"
$installerPath = "$env:TEMP\PowerShell-$latestVersion-win-x64.msi"

Write-Host "[INFO] Downloading PowerShell $latestVersion..."
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

# Install silently
Write-Host "[INFO] Installing PowerShell $latestVersion..."
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait

# Check again
if (Test-Path $pwshPath) {
    Write-Host "`n[SUCCESS] PowerShell $latestVersion installed successfully!"
    Write-Host "[INFO] You can now run it using:`n`"$pwshPath`""
} else {
    Write-Host "`n[ERROR] Installation failed or PowerShell 7 not found."
    exit 1
}
