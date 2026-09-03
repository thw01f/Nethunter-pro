# Building the NetHunter Kernel for Spacewar

This document explains how to build the kernel from scratch.

## Host requirements

- Linux (tested on Kali). ~40 GB free disk, 8 GB+ RAM, multi-core CPU.
- **The build path MUST NOT contain spaces or colons.** The kernel Makefile refuses to build otherwise. Use e.g. `~/kernel_build`, never `~/My Folder/...`.

## 1. Install dependencies

```bash
sudo apt update
sudo apt install -y bc bison flex libssl-dev make gcc libc6-dev \
                    libncurses-dev build-essential git zip unzip \
                    python3 ccache lib32z1-dev libxml2-utils \
                    gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
```

## 2. Set up the workspace

```bash
mkdir -p ~/kernel_build && cd ~/kernel_build

# crDroid 11 kernel source (5.4.302 — MUST match the ROM)
git clone --depth=1 -b 15.0 \
  https://github.com/crdroidandroid/android_kernel_nothing_sm7325 crdroid_kernel

# verify it's 5.4.302
head -5 crdroid_kernel/Makefile
```

## 3. Get the correct toolchain

crDroid's `build.config.common` specifies **clang-r416183b** (clang 12). Using a newer clang against this 5.4 kernel produces hundreds of spurious errors — use the exact one:

```bash
cd ~/kernel_build
mkdir -p toolchain && cd toolchain
git clone --depth=1 -b android-12.0.0_r27 \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 clang-r416183b
```

The clang binary lives at `toolchain/clang-r416183b/clang-r416183b/bin/clang` (nested one level).

## 4. Build environment script

The repo ships `scripts/build_env.sh`. It exports:

```bash
export KERNEL_DIR="$HOME/kernel_build/crdroid_kernel"
export CLANG_DIR="$HOME/kernel_build/toolchain/clang-r416183b/clang-r416183b"
export PATH="$CLANG_DIR/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export LLVM=1
export LLVM_IAS=1
```

Source it and confirm you get **clang 12.0.x**:

```bash
source scripts/build_env.sh
clang --version | head -1   # must say clang version 12.0.x
```

## 5. Configure

There are two valid config bases:

### Option A — vendor defconfig (baseline)
```bash
cd ~/kernel_build/crdroid_kernel
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- \
     vendor/lahaina-qgki_defconfig
```

### Option B — crDroid's exact running config (RECOMMENDED — guarantees working WiFi/touch)
Pull the config from a running crDroid 11 device and build from that, so your kernel has the identical working driver set:
```bash
adb shell "su -c 'zcat /proc/config.gz'" > ~/kernel_build/crdroid_running.config
cp ~/kernel_build/crdroid_running.config ~/kernel_build/crdroid_kernel/out/.config
cd ~/kernel_build/crdroid_kernel
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
```

> **Why Option B matters:** the internal WiFi driver is compiled *into* crDroid's kernel. The bare `vendor/lahaina-qgki_defconfig` may not enable it the same way, producing a kernel that boots but has no `wlan0`. Building from crDroid's running config avoids this.

The NetHunter options (HID, UHID, BT_HIDP, BNEP, RFCOMM) are already present in crDroid's config — verify with:
```bash
grep -iE "CONFIG_USB_CONFIGFS_F_HID=|CONFIG_UHID=|CONFIG_BT_HIDP=|CONFIG_BT_BNEP=|CONFIG_BT_RFCOMM=|CONFIG_CFG80211=|CONFIG_MAC80211=|CONFIG_MODULES=" out/.config
```

If any are missing, enable them:
```bash
./scripts/config --file out/.config \
    -e CONFIG_USB_CONFIGFS_F_HID -e CONFIG_UHID \
    -e CONFIG_BT_HIDP -e CONFIG_BT_BNEP -e CONFIG_BT_RFCOMM \
    -e CONFIG_CFG80211_WEXT
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
```

## 6. Compile

```bash
cd ~/kernel_build/crdroid_kernel
source ~/kernel_build/scripts/build_env.sh   # if not already
make -j$(nproc) O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- \
     Image.gz dtbs 2>&1 | tee build.log
```

Output: `out/arch/arm64/boot/Image.gz` (~19 MB) and DTBs under `out/arch/arm64/boot/dts/vendor/qcom/`.

## 7. Custom kernel name (optional)

```bash
./scripts/config --file out/.config \
    --set-str CONFIG_LOCALVERSION "-NetHunter-DroidSpace-by_w01f-GOWTHAMAN"
./scripts/config --file out/.config -d CONFIG_LOCALVERSION_AUTO
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
# rebuild
```
> Kernel version strings allow only letters, digits, `-`, `_`, `.` — no spaces, `+`, or `[ ]`.

## 8. Package into a boot image

crDroid's boot uses a **raw** (uncompressed) kernel, header v3, ramdisk `lz4_legacy`. Swap your kernel into crDroid's original `boot.img` with magiskboot:

```bash
cd ~/kernel_build && mkdir -p repack && cd repack

# get magiskboot from the Magisk APK
unzip -o /path/to/Magisk-v30.7.apk 'lib/x86_64/*' -d magisk_extract
cp magisk_extract/lib/x86_64/libmagiskboot.so ./magiskboot && chmod +x magiskboot

# unpack crDroid's stock boot.img (extract it from the ROM payload with payload_dumper)
cp /path/to/crdroid_boot.img ./boot_original.img
./magiskboot unpack boot_original.img

# decompress YOUR kernel to raw and name it exactly 'kernel'
gunzip -c ~/kernel_build/crdroid_kernel/out/arch/arm64/boot/Image.gz > kernel

# repack — confirm KERNEL_SZ changes vs original (proof your kernel went in)
./magiskboot repack boot_original.img boot-nethunter.img
```

## 9. Root + flash

Patch with Magisk for root (kernel + root in one image), then test non-destructively before flashing permanently. See [INSTALL.md](INSTALL.md).

## Common pitfalls

- **"source directory cannot contain spaces or colons"** → move the build tree to a spaceless path.
- **clang shows v21/v22** → your PATH picked system clang; the r416183b binary is nested at `clang-r416183b/clang-r416183b/bin`.
- **Kernel boots but no `wlan0`** → you built from the bare defconfig instead of crDroid's running config; use Option B.
- **magiskboot repack didn't change KERNEL_SZ** → the replacement file must be named exactly `kernel` and be raw (gunzip'd), not `Image.gz`.
