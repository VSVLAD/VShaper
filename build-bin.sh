#!/usr/bin/env bash
# pipefail гарантирует, что падение fbc до pipe | tee прервет выполнение скрипта
set -e
set -o pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
BIN_DIR="$PROJECT_ROOT/bin"
APK_BIN_DIR="$PROJECT_ROOT/apk/root/usr/bin"

BIN_NAME="vshaper"
BUILD_LOG="$PROJECT_ROOT/bin/build.log"

mkdir -p "$BIN_DIR"
mkdir -p "$APK_BIN_DIR"

echo "=========================================="
echo "Компиляция $BIN_NAME (ARM64 static)..."
echo "=========================================="

# Удаляем старый бинарник во всех каталогах, чтобы исключить ложный успех
rm -f "$BIN_DIR/$BIN_NAME"
rm -f "$APK_BIN_DIR/$BIN_NAME"

# Флаг -w error превращает все синтаксические предупреждения (включая незакрытые кавычки) в фатальные ошибки
if ! fbc -target aarch64-linux-gnu -gen gcc -static -w error \
    "$SRC_DIR/program.bas" \
    -x "$BIN_DIR/$BIN_NAME" 2>&1 | tee "$BUILD_LOG"; then
    echo ""
    echo "[-] ОШИБКА КОМПИЛЯЦИИ! Сборка остановлена."
    echo "    Лог сохранён в: $BUILD_LOG"
    exit 1
fi

if [ ! -f "$BIN_DIR/$BIN_NAME" ]; then
    echo "[-] Файл $BIN_DIR/$BIN_NAME не найден после компиляции!"
    exit 1
fi

# Копируем свежий бинарник в дерево пакета
cp "$BIN_DIR/$BIN_NAME" "$APK_BIN_DIR/$BIN_NAME"
chmod +x "$APK_BIN_DIR/$BIN_NAME"

BIN_SIZE=$(ls -lh "$BIN_DIR/$BIN_NAME" | awk '{print $5}')
echo "[+] Сборка успешна!"
echo "[+] Бинарник сохранён в: bin/$BIN_NAME ($BIN_SIZE)"
echo "[+] Синхронизирован в:   apk/root/usr/bin/$BIN_NAME"