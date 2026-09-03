#!/bin/bash
# Automated build for the crDroid-based NetHunter kernel — Nothing Phone 1 (spacewar)
# Usage:
#   ./scripts/build.sh                 # build from crDroid running config if present, else vendor defconfig
#   CONFIG_MODE=vendor ./scripts/build.sh   # force vendor defconfig
#   KNAME="-my-name" ./scripts/build.sh     # set a custom LOCALVERSION
#
# Requires: deps installed, sources + toolchain in ~/kernel_build (see docs/BUILD.md)

set -e

BASE="$HOME/kernel_build"
KERNEL_DIR="$BASE/crdroid_kernel"
RUNNING_CFG="$BASE/crdroid_running.config"
JOBS="$(nproc)"
KNAME="${KNAME:-}"
CONFIG_MODE="${CONFIG_MODE:-auto}"

# --- sanity: no spaces in path ---
case "$BASE" in
  *" "*|*":"*) echo "ERROR: build path '$BASE' contains a space or colon. Move it."; exit 1;;
esac

# --- toolchain ---
# shellcheck disable=SC1091
source "$(dirname "$0")/build_env.sh"

CLANG_VER="$(clang --version 2>/dev/null | head -1)"
case "$CLANG_VER" in
  *"version 12."*) : ;;
  *) echo "WARNING: clang is not 12.x — build may fail. Got: $CLANG_VER";;
esac

cd "$KERNEL_DIR"
mkdir -p out

MAKE_ARGS=(O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu-)

# --- configure ---
if { [ "$CONFIG_MODE" = "auto" ] && [ -f "$RUNNING_CFG" ]; } || [ "$CONFIG_MODE" = "running" ]; then
  echo ">> Using crDroid running config: $RUNNING_CFG"
  cp "$RUNNING_CFG" out/.config
  make "${MAKE_ARGS[@]}" olddefconfig
else
  echo ">> Using vendor/lahaina-qgki_defconfig"
  make "${MAKE_ARGS[@]}" vendor/lahaina-qgki_defconfig
fi

# --- ensure NetHunter options ---
echo ">> Ensuring NetHunter config options"
./scripts/config --file out/.config \
    -e CONFIG_USB_CONFIGFS_F_HID \
    -e CONFIG_UHID \
    -e CONFIG_HID \
    -e CONFIG_BT_HIDP \
    -e CONFIG_BT_BNEP \
    -e CONFIG_BT_BNEP_MC_FILTER \
    -e CONFIG_BT_BNEP_PROTO_FILTER \
    -e CONFIG_BT_RFCOMM \
    -e CONFIG_BT_RFCOMM_TTY \
    -e CONFIG_CFG80211 \
    -e CONFIG_CFG80211_WEXT \
    -e CONFIG_MAC80211 \
    -e CONFIG_MODULES \
    -e CONFIG_MODULE_UNLOAD \
    -e CONFIG_USB

# --- custom name ---
if [ -n "$KNAME" ]; then
  echo ">> Setting LOCALVERSION: $KNAME"
  ./scripts/config --file out/.config --set-str CONFIG_LOCALVERSION "$KNAME"
  ./scripts/config --file out/.config -d CONFIG_LOCALVERSION_AUTO
fi

make "${MAKE_ARGS[@]}" olddefconfig

# --- verify key options ---
echo ">> Config verification:"
grep -iE "CONFIG_USB_CONFIGFS_F_HID=|CONFIG_UHID=|CONFIG_BT_HIDP=|CONFIG_BT_BNEP=|CONFIG_BT_RFCOMM=|CONFIG_CFG80211=|CONFIG_MAC80211=|CONFIG_MODULES=" out/.config || true

# --- build ---
echo ">> Building (jobs=$JOBS)"
make -j"$JOBS" "${MAKE_ARGS[@]}" Image.gz dtbs 2>&1 | tee "$BASE/build.log"

IMG="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"
if [ -f "$IMG" ]; then
  echo ""
  echo "SUCCESS: $IMG ($(du -h "$IMG" | cut -f1))"
  echo "Next: package with scripts/repack.sh (see docs/BUILD.md)"
else
  echo "BUILD FAILED — check $BASE/build.log"
  exit 1
fi
