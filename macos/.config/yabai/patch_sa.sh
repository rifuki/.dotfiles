#!/usr/bin/env bash
set -e

# Pastikan dijalankan sebagai root / sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: Jalankan script ini dengan sudo: sudo $0"
    exit 1
fi

LOADER="/Library/ScriptingAdditions/yabai.osax/Contents/MacOS/loader"

if [ ! -f "$LOADER" ]; then
    echo "yabai.osax belum terinstall, mencoba install..."
    yabai --load-sa || true
fi

if [ ! -f "$LOADER" ]; then
    echo "Error: '$LOADER' tidak ditemukan!"
    exit 1
fi

echo "Memeriksa PAC ABI capabilities pada $LOADER..."
read I O <<< $(otool -f "$LOADER" | awk '/architecture/{i=$2} /capabilities 0x81/{f=1} f&&/offset/{print i, $2; exit}')

if [ -n "$O" ]; then
    echo "Ditemukan PAC ABI v1 (capabilities 0x81). Mem-patch ke PAC ABI v0 (0x80) untuk kompatibilitas Dock.app Sequoia..."
    printf '\x80' | dd of="$LOADER" bs=1 seek=$((8 + I*20 + 4)) count=1 conv=notrunc 2>/dev/null
    printf '\x80' | dd of="$LOADER" bs=1 seek=$((O + 11)) count=1 conv=notrunc 2>/dev/null
    
    echo "Menandatangani ulang biner loader (codesign)..."
    codesign -f -s - "$LOADER"
    echo "Patch berhasil diterapkan!"
else
    echo "Loader sudah menggunakan capabilities 0x80 atau tidak memerlukan patch."
fi

echo "Mencoba memuat Scripting Addition..."
yabai --load-sa
echo "Scripting Addition berhasil dimuat ke Dock.app!"
