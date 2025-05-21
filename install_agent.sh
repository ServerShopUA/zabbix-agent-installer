#!/bin/bash

# === Налаштування ===
ZABBIX_SERVER="monitor.server-shop.ua"
AGENT_VERSION="7.2"

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

    # Якщо це Proxmox, перевизначаємо змінні
    if grep -qi proxmox /etc/os-release; then
        DISTRO="debian"
        VERSION="11"
        echo "[INFO] Виявлено Proxmox — використовується як Debian $VERSION"
    fi
else
    echo "[ERROR] Неможливо визначити ОС"
    exit 1
fi

# === Встановлення репозиторію Zabbix та агента ===
if [[ "$DISTRO" == "ubuntu" ]]; then
    PACKAGE="zabbix-release_latest+ubuntu${VERSION}_all.deb"
    URL="https://repo.zabbix.com/zabbix/${AGENT_VERSION}/release/ubuntu/pool/main/z/zabbix-release/${PACKAGE}"
elif [[ "$DISTRO" == "debian" ]]; then
    VERSION_MAJOR="${VERSION%%.*}"
    PACKAGE="zabbix-release_latest+debian${VERSION_MAJOR}_all.deb"
    URL="https://repo.zabbix.com/zabbix/${AGENT_VERSION}/release/debian/pool/main/z/zabbix-release/${PACKAGE}"
elif [[ "$DISTRO" == "centos" ]]; then
    echo "[INFO] Виявлено CentOS/RHEL $VERSION"
    # Використовуємо стабільний 7.0 репозиторій
    PACKAGE="zabbix-release-7.0-1.el7.noarch.rpm"
    URL="https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/${PACKAGE}"
    echo "[INFO] Завантаження репозиторію Zabbix..."
    curl -s -o "/tmp/$PACKAGE" "$URL" || { echo "[ERROR] Не вдалося завантажити $PACKAGE"; exit 1; }
    rpm -Uvh "/tmp/$PACKAGE" || { echo "[ERROR] Не вдалося встановити $PACKAGE"; exit 1; }
    yum clean all
    yum install -y zabbix-agent
else
    echo "[ERROR] Невідома або не підтримувана ОС: $DISTRO"
    exit 1
fi

echo "[INFO] Завантаження репозиторію Zabbix..."
wget -q "$URL" -O "/tmp/$PACKAGE" || { echo "[ERROR] Не вдалося завантажити $PACKAGE"; exit 1; }
dpkg -i "/tmp/$PACKAGE" || { echo "[ERROR] dpkg не зміг встановити $PACKAGE"; exit 1; }
apt update
apt install -y zabbix-agent || { echo "[ERROR] Не вдалося встановити zabbix-agent"; exit 1; }

# === Створення необхідної директорії ===
CONF_DIR="/etc/zabbix/zabbix_agentd.conf.d"
if [ ! -d "$CONF_DIR" ]; then
    echo "[INFO] Створюється відсутня директорія $CONF_DIR"
    mkdir -p "$CONF_DIR"
fi

# === Налаштування агента ===
CONF="/etc/zabbix/zabbix_agentd.conf"
if [ -f "$CONF" ]; then
    sed -i "s/^Server=.*/Server=${ZABBIX_SERVER}/" "$CONF"
    sed -i "s/^ServerActive=.*/ServerActive=${ZABBIX_SERVER}/" "$CONF"
    sed -i "s/^Hostname=.*/Hostname=${HOSTNAME}/" "$CONF"
else
    echo "[WARN] Конфіг $CONF не знайдено — перевір вручну"
fi

# === Кастомні параметри для Proxmox ===
if grep -qi proxmox /etc/os-release; then
    cat <<EOF > "$CONF_DIR/proxmox.conf"
UserParameter=proxmox.lxc.count,lxc-ls | wc -l
UserParameter=proxmox.kvm.count,qm list | grep -v VMID | wc -l
EOF
    echo "[INFO] Додано кастомні UserParameter для Proxmox"
fi

# === Запуск агента ===
if systemctl list-unit-files | grep -q zabbix-agent.service; then
    systemctl enable zabbix-agent
    systemctl restart zabbix-agent
    echo "✅ Агент встановлено і запущено. Hostname: $HOSTNAME"
else
    echo "[ERROR] Служба zabbix-agent не знайдена — можливо щось пішло не так"
    exit 1
fi