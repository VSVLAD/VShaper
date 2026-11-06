#!/usr/bin/env bash
set -e

# Подгружаем .env файл, если он существует
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    . "$PROJECT_ROOT/.env"
    set +a
fi

# ================= КОНФИГУРАЦИЯ РОУТЕРА =================
ROUTER_IP="192.168.1.1"
# =======================================================

export SSHPASS="$ROUTER_PASS"

echo "=========================================="
echo "Подключение к OpenWrt ($ROUTER_IP)..."
echo "Для выхода из сессии наберите 'exit'"
echo "=========================================="

# -t форсирует псевдотерминал (TTY) для интерактивной работы в ash/sh
sshpass -e ssh -t -o ConnectTimeout=3 -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}"