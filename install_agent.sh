#!/bin/bash

# === Налаштування ===
ZABBIX_SERVER="monitor.server-shop.ua"
AGENT_VERSION="7.2"

# === Автоматичне визначення hostname
HOSTNAME=$(hostname -f 2>/dev/null)

# Якщо пусто — генеруємо
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="client-$(date +%s)"
    echo "[WARN] Не вдалося отримати hostname системи, згенеровано: $HOSTNAME"
else
    echo "[INFO] Використовується hostname: $HOSTNAME"
fi

# === Визначення дистрибутива ===
if [ -f /etc/debian_version ]; then
    OS="debian"
    VERSION_ID=$(lsb_release -rs | cut -d. -f1)
    PACKAGE="zabbix-release_${AGENT_VERSION}-1+debian${VERSION_ID}_all.deb"
    URL="https://repo.zabbix.com/zabbix/${AGENT_VERSION}/debian/pool/main/z/zabbix-release/${PACKAGE}"

    wget -q $URL -O /tmp/$PACKAGE
    dpkg -i /tmp/$PACKAGE
    apt update
    apt install -y zabbix-agent

elif [ -f /etc/redhat-release ]; then
    OS="rhel"
    VERSION_ID=$(rpm -E %{rhel})
    rpm -Uvh "https://repo.zabbix.com/zabbix/${AGENT_VERSION}/rhel/${VERSION_ID}/x86_64/zabbix-release-${AGENT_VERSION}-1.el${VERSION_ID}.noarch.rpm"
    yum clean all
    yum install -y zabbix-agent
else
    echo "[ERROR] Невідома ОС"
    exit 1
fi

# === Налаштування агента ===
CONF="/etc/zabbix/zabbix_agentd.conf"
sed -i "s/^Server=.*/Server=${ZABBIX_SERVER}/" $CONF
sed -i "s/^ServerActive=.*/ServerActive=${ZABBIX_SERVER}/" $CONF
sed -i "s/^Hostname=.*/Hostname=${HOSTNAME}/" $CONF

# === Запуск ===
systemctl enable zabbix-agent
systemctl restart zabbix-agent

echo "✅ Агент встановлено і запущено. Hostname: $HOSTNAME"