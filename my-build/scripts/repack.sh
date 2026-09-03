#!/bin/bash
# Repack the compiled kernel into crDroid's boot.img using magiskboot.
# Usage:
#   ./scripts/repack.sh /path/to/crdroid_stock_boot.img /path/to/Magisk-vXX.apk
#
# Produces: ~/kernel_build/repack/boot-nethunter.img
# Then patch that with Magisk for root, TEST with `fastboot boot`, then flash.

set -e

STOCK_BOOT="$1"
MAGISK_APK="$2"
BASE="$HOME/kernel_build"
KIMG="$BASE/crdroid_kernel/out/arch/arm64/boot/Image.gz"
WORK="$BASE/repack"

if [ -z "$STOCK_BOOT" ] || [ -z "$MAGISK_APK" ]; then
  echo "Usage: $0 <crdroid_stock_boot.img> <Magisk.apk>"
  exit 1
fi
[ -f "$KIMG" ] || { echo "Kernel not found: $KIMG (build first)"; exit 1; }

mkdir -p "$WORK" && cd "$WORK"

# get magiskboot from the APK (x86_64 host)
if [ ! -x ./magiskboot ]; then
  rm -rf magisk_extract
  unzip -o "$MAGISK_APK" 'lib/x86_64/*' -d magisk_extract >/dev/null
  cp magisk_extract/lib/x86_64/libmagiskboot.so ./magiskboot
  chmod +x ./magiskboot
fi

cp "$STOCK_BOOT" ./boot_original.img
./magiskboot cleanup 2>/dev/null || true
./magiskboot unpack boot_original.img

# crDroid boot uses a RAW kernel; decompress ours and name it exactly 'kernel'
gunzip -c "$KIMG" > kernel

./magiskboot repack boot_original.img boot-nethunter.img

echo ""
echo "Built: $WORK/boot-nethunter.img"
echo "Verify KERNEL_SZ above differs from the original (proof your kernel went in)."
echo ""
echo "Next steps:"
echo "  adb push boot-nethunter.img /sdcard/Download/"
echo "  # Magisk app -> Install -> Select and Patch a File -> boot-nethunter.img"
echo "  adb pull /sdcard/Download/magisk_patched-XXXXX.img ."
echo "  adb reboot bootloader"
echo "  fastboot boot magisk_patched-XXXXX.img     # TEST first (non-destructive)"
echo "  # if wifi/touch/root ok: fastboot flash boot magisk_patched-XXXXX.img"
