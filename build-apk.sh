#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="$PROJECT_ROOT/bin/vshaper"
PKG_ROOT="$PROJECT_ROOT/apk/root"
RELEASE_DIR="$PROJECT_ROOT/release"

# ================= ПАРАМЕТРЫ ПАКЕТА =================
PKG_NAME="luci-app-vshaper"
PKG_VER="1.0.0-r1"
PKG_DESC="Traffic Shaper WebUI and engine based on TC"
PKG_DEPS="tc-tiny nftables-json luci-base"

# Список целевых архитектур для мультисборки
TARGET_ARCHS=(
    "aarch64_cortex-a53"
    "aarch64_cortex-a72"
    "aarch64_generic"
)
# ====================================================

if [ ! -f "$BIN_PATH" ]; then
    echo "[-] Ошибка: $BIN_PATH не найден! Сначала запустите сборку бинарника."
    exit 1
fi

APK_BIN="$(command -v apk || true)"
[ -z "$APK_BIN" ] && [ -x "/usr/local/bin/apk" ] && APK_BIN="/usr/local/bin/apk"
if [ -z "$APK_BIN" ]; then
    echo "[-] Утилита apk не найдена в WSL (/usr/local/bin/apk)!"
    exit 1
fi

# Подготовка структуры
mkdir -p "$PKG_ROOT/usr/bin" "$RELEASE_DIR"
cp "$BIN_PATH" "$PKG_ROOT/usr/bin/vshaper"
chmod 755 "$PKG_ROOT/usr/bin/vshaper"
[ -f "$PKG_ROOT/etc/init.d/vshaper" ] && chmod 755 "$PKG_ROOT/etc/init.d/vshaper"

# Создаем список файлов пакета (.list)
mkdir -p "$PKG_ROOT/lib/apk/packages"
rm -f "$PKG_ROOT/lib/apk/packages/${PKG_NAME}.list"
(cd "$PKG_ROOT" && find . -type f -o -type l | sed 's|^\.||') > "$PKG_ROOT/lib/apk/packages/${PKG_NAME}.list"

# Функция сборки единичного APK
build_single_apk() {
    local target_arch="$1"
    local out_apk="${RELEASE_DIR}/${PKG_NAME}-${PKG_VER}_${target_arch}.apk"

    rm -f "$out_apk"
    "$APK_BIN" mkpkg \
        -o "$out_apk" \
        -s "pre-install:$PROJECT_ROOT/apk/pre-install.sh" \
        -s "post-install:$PROJECT_ROOT/apk/post-install.sh" \
        -s "pre-deinstall:$PROJECT_ROOT/apk/pre-deinstall.sh" \
        -s "post-deinstall:$PROJECT_ROOT/apk/post-deinstall.sh" \
        -F "$PKG_ROOT" \
        -I "name:$PKG_NAME" \
        -I "version:$PKG_VER" \
        -I "description:$PKG_DESC" \
        -I "arch:$target_arch" \
        -I "provider-priority:100" \
        -I "depends:$PKG_DEPS"

    local sz=$(ls -lh "$out_apk" | awk '{print $5}')
    echo "[+] Собран: $(basename "$out_apk") ($sz)"
}

echo "=========================================="
if [ "$1" == "all" ]; then
    echo "Массовая сборка APK под все таргеты ARM64..."
    echo "=========================================="
    for arch in "${TARGET_ARCHS[@]}"; do
        build_single_apk "$arch"
    done
else
    echo "Сборка APK для рабочего стенда (aarch64_cortex-a53)..."
    echo "=========================================="
    build_single_apk "aarch64_cortex-a53"
fi