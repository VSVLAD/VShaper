#!/usr/bin/env bash
set -e

# ================= КОНФИГУРАЦИЯ РОУТЕРА =================
ROUTER_IP="192.168.1.1"
TARGET_DIR="/tmp"
# =======================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$PROJECT_ROOT/release"
TARGET_ARCH="aarch64_cortex-a53"
PKG_FILE=$(ls -t "$RELEASE_DIR"/*_"${TARGET_ARCH}".apk 2>/dev/null | head -n 1)

# Подгружаем .env файл, если он существует
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    . "$PROJECT_ROOT/.env"
    set +a
fi

if [ -z "$PKG_FILE" ] || [ ! -f "$PKG_FILE" ]; then
    echo "[-] Ошибка: Пакет для ${TARGET_ARCH} не найден в release/!"
    exit 1
fi

export SSHPASS="$ROUTER_PASS"
SSH_CMD="sshpass -e ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no"

# Извлекаем имя пакета из названия файла (например, luci-app-vshaper-1.0.0-r1_aarch64... -> luci-app-vshaper)
APK_NAME=$(basename "$PKG_FILE")
PKG_NAME=$(echo "$APK_NAME" | sed -E 's/-[0-9]+\.[0-9]+.*//')

echo "=========================================="
echo "Деплой $APK_NAME (пакет: $PKG_NAME) на $ROUTER_IP..."
echo "=========================================="

# Передаем APK через SSH pipe в /tmp
cat "$PKG_FILE" | $SSH_CMD "${ROUTER_USER}@${ROUTER_IP}" "cat > ${TARGET_DIR}/${APK_NAME}"

echo "[*] Удаление старой версии пакета..."
$SSH_CMD "${ROUTER_USER}@${ROUTER_IP}" "apk del $PKG_NAME"
echo "[+] Удаление выполнено."

# Устанавливаем пакет
echo "[*] Установка пакета..."
$SSH_CMD "${ROUTER_USER}@${ROUTER_IP}" "apk add --allow-untrusted ${TARGET_DIR}/${APK_NAME}"
echo "[+] Установка завершена!"