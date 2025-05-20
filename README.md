# Zabbix Agent Installer

Цей репозиторій містить скрипти для швидкого підключення Linux або Windows-серверів до нашого Zabbix моніторингу.

## Linux (Debian/Ubuntu/CentOS)

```bash
curl -s https://raw.githubusercontent.com/ServerShopUA/zabbix-agent-installer/main/install_agent.sh | bash
```

## Windows (PowerShell)
```powershell
iwr https://raw.githubusercontent.com/ServerShopUA/zabbix-agent-installer/main/install_agent_win.ps1 -OutFile "$env:TEMP\install_agent_win.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\install_agent_win.ps1"
```

## Оновлення PowerShell 7

якщо виникає помилка на етапі Expand-Archive - можливо старий powershell
ось як його оновити

Відкрий PowerShell від імені адміністратора та виконай:
```powershell
iwr https://raw.githubusercontent.com/ServerShopUA/zabbix-agent-installer/main/install_or_update_pwsh.ps1 -OutFile "$env:TEMP\install_or_update_pwsh.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\install_or_update_pwsh.ps1"
```

PowerShell 7 встановлюється за шляхом:
```
C:\Program Files\PowerShell\7\pwsh.exe
```


	