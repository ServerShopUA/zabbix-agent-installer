#!/bin/bash

# === Налаштування ===
ZABBIX_SERVER="monitor.server-shop.ua"
AGENT_VERSION="7.2"
AGENT2_RPM="zabbix-agent2-7.0.9-release1.el7.x86_64.rpm"
AGENT2_URL="https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/"

# === Автоматичне визначення hostname ===
HOSTNAME=$(hostname -f 2>/dev/null)
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="client-$(date +%s)"
    echo "[WARN] Не вдалося отримати hostname системи, згенеровано: $HOSTNAME"
else
    echo "[INFO] Використовується hostname: $HOSTNAME"
fi

# === Визначення дистрибутива ===
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID

    if grep -qi proxmox /etc/os-release; then
        DISTRO="debian"
        VERSION="11"
        echo "[INFO] Виявлено Proxmox — використовується як Debian $VERSION"
    fi
else
    echo "[ERROR] Неможливо визначити ОС"
    exit 1
fi

# === Встановлення агента ===
if [[ "$DISTRO" == "ubuntu" ]]; then
    PACKAGE="zabbix-release_latest+ubuntu${VERSION}_all.deb"
    URL="https://repo.zabbix.com/zabbix/${AGENT_VERSION}/release/ubuntu/pool/main/z/zabbix-release/${PACKAGE}"
    echo "[INFO] Завантаження Zabbix репозиторію для Ubuntu $VERSION..."
    wget -q "$URL" -O "/tmp/$PACKAGE" || { echo "[ERROR] Не вдалося завантажити $PACKAGE"; exit 1; }
    dpkg -i "/tmp/$PACKAGE" || { echo "[ERROR] dpkg не зміг встановити $PACKAGE"; exit 1; }
    apt update
    apt install -y zabbix-agent || { echo "[ERROR] Не вдалося встановити zabbix-agent"; exit 1; }

elif [[ "$DISTRO" == "debian" ]]; then
    VERSION_MAJOR="${VERSION%%.*}"
    PACKAGE="zabbix-release_latest+debian${VERSION_MAJOR}_all.deb"
    URL="https://repo.zabbix.com/zabbix/${AGENT_VERSION}/release/debian/pool/main/z/zabbix-release/${PACKAGE}"
    echo "[INFO] Завантаження Zabbix репозиторію для Debian $VERSION_MAJOR..."
    wget -q "$URL" -O "/tmp/$PACKAGE" || { echo "[ERROR] Не вдалося завантажити $PACKAGE"; exit 1; }
    dpkg -i "/tmp/$PACKAGE" || { echo "[ERROR] dpkg не зміг встановити $PACKAGE"; exit 1; }
    apt update
    apt install -y zabbix-agent || { echo "[ERROR] Не вдалося встановити zabbix-agent"; exit 1; }

elif [[ "$DISTRO" == "centos" && "$VERSION" == "7" ]]; then
    echo "[INFO] Виявлено CentOS 7 — встановлення Zabbix Agent2 напряму"
    echo "[INFO] URL: ${AGENT2_URL}${AGENT2_RPM}"
    curl -s -o "/tmp/${AGENT2_RPM}" "${AGENT2_URL}${AGENT2_RPM}" || { echo "[ERROR] Не вдалося завантажити $AGENT2_RPM"; exit 1; }
    rpm -Uvh "/tmp/$AGENT2_RPM" || { echo "[ERROR] rpm не зміг встановити $AGENT2_RPM"; exit 1; }

else
    echo "[ERROR] Невідома або не підтримувана ОС: $DISTRO $VERSION"
    exit 1
fi

# === Створення директорії під UserParameter ===
CONF_DIR="/etc/zabbix/zabbix_agentd.conf.d"
[ -d "$CONF_DIR" ] || { echo "[INFO] Створюється $CONF_DIR"; mkdir -p "$CONF_DIR"; }

# === Налаштування агента ===
CONF="/etc/zabbix/zabbix_agentd.conf"
if [ -f "$CONF" ]; then
    sed -i "s|^Server=.*|Server=${ZABBIX_SERVER}|" "$CONF"
    sed -i "s|^ServerActive=.*|ServerActive=${ZABBIX_SERVER}|" "$CONF"
    sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" "$CONF"
else
    echo "[WARN] $CONF не знайдено — пропускаємо зміну конфігурації"
fi

# === Кастомні UserParameter для Proxmox ===
if grep -qi proxmox /etc/os-release; then
    cat <<EOF > "$CONF_DIR/proxmox.conf"
UserParameter=proxmox.lxc.count,lxc-ls | wc -l
UserParameter=proxmox.kvm.count,qm list | grep -v VMID | wc -l
EOF
    echo "[INFO] Додано кастомні UserParameter для Proxmox"
fi

# === Запуск служби ===
if systemctl list-unit-files | grep -q zabbix-agent.service; then
    systemctl enable zabbix-agent
    systemctl restart zabbix-agent
    echo "✅ Zabbix agentd запущено"
elif systemctl list-unit-files | grep -q zabbix-agent2.service; then
    systemctl enable zabbix-agent2
    systemctl restart zabbix-agent2
    echo "✅ Zabbix agent2 запущено"
else
    echo "[ERROR] Zabbix агент не знайдено після встановлення"
    exit 1
fi

echo "🎯 Завершено. Hostname: $HOSTNAME"