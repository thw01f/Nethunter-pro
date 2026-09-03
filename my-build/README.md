# NetHunter Kernel for Nothing Phone (1) — Spacewar

A NetHunter-capable custom kernel for the **Nothing Phone (1)** (codename `spacewar`, SoC Qualcomm SM7325 / Snapdragon 778G+), built from **crDroid 11 (Android 15)** kernel source.

Maintainer: **w01f [GOWTHAMAN]**

---

## What this is

This kernel is built from crDroid's official `android_kernel_nothing_sm7325` source (kernel `5.4.302`, matching crDroid 11 / Nothing OS 3.2 base) and is configured with the full set of Kali NetHunter kernel features that this hardware actually supports.

It boots on **crDroid 11 (Android 15)** and preserves working WiFi, touch, and Bluetooth while enabling NetHunter's attack surface.

## Capabilities

### Confirmed working (internal, no extra hardware)

| Feature | Status | Notes |
|---|---|---|
| USB HID gadget / BadUSB (keyboard + mouse injection) | ✅ | `CONFIG_USB_CONFIGFS_F_HID`, `CONFIG_UHID` |
| Full Kali NetHunter chroot + tools | ✅ | standard NetHunter app/chroot install |
| USB gadget ConfigFS (RNDIS, ACM, NCM, MASS_STORAGE, etc.) | ✅ | full gadget stack |
| Internal WiFi (station/AP, normal connectivity) | ✅ | in-kernel Qualcomm driver, works normally |
| Bluetooth protocol stack (BT_HIDP, BT_BNEP, BT_RFCOMM) | ✅ | kernel-level support — see limitation below for what this does *not* unlock |
| Module loading + unload | ✅ | `CONFIG_MODULES`, `CONFIG_MODULE_UNLOAD` |

### Requires an external USB adapter (hardware limitation, not the kernel)

| Feature | Adapter | Notes |
|---|---|---|
| WiFi monitor mode / injection | ath9k_htc, mt7612u, rtl88xxau chipsets | Internal WCN6750 firmware never exposes monitor mode |
| Bluetooth attacks via BlueZ (bluetoothctl, hcitool, BlueDucky, etc.) | CSR8510 / RTL8761 USB dongle | Exposes `hci0` — internal chip does not (see below) |

See **[docs/EXTERNAL_ADAPTERS.md](docs/EXTERNAL_ADAPTERS.md)** for adapter recommendations and setup.

### Not possible on this hardware

- **Internal WiFi injection** — the WCN6750 firmware doesn't expose monitor mode. No kernel change can add it.
- **Internal Bluetooth via BlueZ** — the internal BT chip is UART/HAL-bound (Android's own Bluetooth stack path), not a standard HCI transport. There is no `hci0`; `hciattach qca` is unsupported on this wiring. The kernel's `BT_HIDP`/`BT_BNEP`/`BT_RFCOMM` config is real, but those protocols run on top of an HCI controller that doesn't exist here — they have nothing to bind to without an external dongle.

## Requirements to run

- Nothing Phone (1) — `spacewar`
- Unlocked bootloader
- **crDroid 11 (Android 15)** installed (based on Nothing OS 3.2 firmware)
- Magisk (for root — required by NetHunter)

## Installation (for users)

See **[docs/INSTALL.md](docs/INSTALL.md)** for full step-by-step flashing instructions.

Quick version:
1. Download `boot-nethunter.img` from [Releases](../../releases)
2. Patch it with Magisk (or flash the pre-patched image if provided)
3. Test non-destructively: `fastboot boot boot-nethunter.img`
4. If WiFi/touch/root all work, flash permanently: `fastboot flash boot boot-nethunter.img`
5. Install the NetHunter app + chroot

## Building from source

See **[docs/BUILD.md](docs/BUILD.md)**. TL;DR:

```bash
./scripts/build.sh
```

## Findings & the story behind this

See **[docs/FINDINGS.md](docs/FINDINGS.md)** — a detailed writeup of what works, what doesn't, and the dead ends (kimocoder kernel wifi break, DroidSpace base-mismatch, why the base must be NOS 3.2, etc.). If you're porting NetHunter to spacewar, read this first; it will save you days.

## Credits

- crDroid team — kernel source (`android_kernel_nothing_sm7325`)
- ExCP/ExTV — DroidSpace kernel reference (spacewar NetHunter research)
- aircrack-ng — external WiFi adapter drivers
- osm0sis — AnyKernel3, magiskboot
- Kali NetHunter / OffSec
- spike0en — Nothing Archive (stock firmware)

## Disclaimer

Provided as-is. Flashing custom kernels carries risk of bootloop or data loss. You are responsible for what you flash. For authorized security testing and education only.
