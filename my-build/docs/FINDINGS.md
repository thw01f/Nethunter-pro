# Findings — NetHunter on Nothing Phone (1) Spacewar

A practical record of what works, what doesn't, and the dead ends — so the next person doesn't lose days. Device: Nothing Phone (1), codename `spacewar`, SoC **Qualcomm SM7325 (Snapdragon 778G+)**, WiFi/BT **WCN6750**.

## TL;DR

- **Internal WiFi injection is impossible on this device.** WCN6750 firmware doesn't expose monitor mode. No kernel fixes it. Use an external USB adapter.
- **HID/BadUSB attacks DO work internally** — crDroid 11's kernel already ships `CONFIG_USB_CONFIGFS_F_HID`, `CONFIG_UHID`.
- **Bluetooth attacks do NOT work against the internal chip** — the kernel ships `CONFIG_BT_HIDP`, `CONFIG_BT_BNEP`, `CONFIG_BT_RFCOMM`, but the internal BT radio has no `hci0` for BlueZ to bind to (UART/HAL-bound, `hciattach qca` unsupported). Needs an external USB BT dongle. See "The internal Bluetooth wall" below.
- **The base firmware version matters more than anything.** Custom NetHunter/DroidSpace kernels are built against a specific base; flashing them on the wrong base hangs at boot.
- The internal WiFi driver is **compiled into** crDroid's kernel (not a `.ko` module) — so a rebuild must include the same WiFi config or you get a kernel that boots with **no `wlan0`**.

## The WCN6750 WiFi injection wall

The headline NetHunter kernel feature is internal-radio monitor mode + packet injection. On WCN6750 this is gated in the **signed firmware blob**, not the driver. The chip rejects modified firmware. There is no nexmon equivalent for Qualcomm WCN6750. Even the maintainer of the official NetHunter spacewar kernel notes WiFi doesn't work properly on this SoC.

**Consequence:** for airodump/deauth/handshake/evil-twin you need an **external USB adapter** over a powered OTG hub. This is normal for mobile pentesting regardless of phone.

Recommended adapters:
- **Alfa AWUS036ACM** (MediaTek MT7612U) — dual-band, mainline driver, reliable injection. Best pick.
- **Alfa AWUS036NHA** (Atheros AR9271) — 2.4 GHz only, `ath9k_htc` in-kernel, bulletproof, cheap.
- **Alfa AWUS036ACH** (RTL8812AU) — dual-band, powerful, but out-of-tree driver, finickier.

## The internal Bluetooth wall

The same WCN6750 combo chip handles Bluetooth, and it has an analogous problem to the WiFi injection wall — just for a different reason.

The internal BT radio is wired up as a **UART-attached, HAL-bound** controller — the transport Android's own Bluetooth stack (Fluoride) expects, not a standard HCI transport BlueZ can bind to. Concretely:

- No `hci0` is ever created for the internal chip — `hciconfig`/`bluetoothctl list` show nothing.
- `hciattach qca`, the normal way to bring a Qualcomm UART Bluetooth chip up as an HCI device on Linux, **does not work** on this device's UART wiring/firmware path.
- The kernel's `CONFIG_BT_HIDP`, `CONFIG_BT_BNEP`, `CONFIG_BT_RFCOMM` are genuinely enabled — but they're protocol layers that run *on top of* an HCI controller. With no `hci0`, they have nothing to attach to. **Kernel config presence proves the protocol stack exists, not that BlueZ can drive it against this hardware.**

**Consequence:** BlueZ-based Bluetooth attacks (bluetoothctl, hcitool, BlueDucky, etc.) need an external USB Bluetooth dongle (CSR8510 or RTL8761 chipset — both use the in-kernel `btusb` driver and expose a normal `hci0`). See `docs/EXTERNAL_ADAPTERS.md`.

This is the same lesson as the WiFi wall: **a kernel config option being `=y` tells you the protocol code is compiled in, not that the specific hardware path to use it exists.** Always verify the actual device node/interface (`wlan0`, `hci0`) shows up before assuming a feature works.

## Dead end #1 — the generic/kimocoder NetHunter kernel

The official NetHunter kernel zip (kimocoder build, ~`5.4.271-NetHunter`, targeting Android 12/13/14) installs via Magisk. On this device it **boots but WiFi never comes up** — `icnss2: WLAN FW is ready` appears in dmesg (firmware inits) but **no `wlan0` netdev is ever created**. There is no wlan `.ko` to load; the driver is built-in and simply doesn't register on that kernel.

Additional observations on that kernel: HID reportedly didn't work either, and Bluetooth misbehaved. Net: it loses WiFi and delivers little in return on this SoC.

**Do not** try to "fix" its WiFi by reflashing the stock boot on top — that creates a boot/vendor mismatch and bootloops.

## Dead end #2 — DroidSpace kernel on the wrong base

ExCP/ExTV's **DroidSpace kernel** (`5.4.289-droidspace`) is genuinely good — built from Nothing's official msm-5.4 source, with HID, USB gadget ConfigFS, BT HID, containers/Docker. But it is built against **stock Nothing OS 3.2** (`Spacewar-V3.2-260206-1016`).

- On **stock NOS 3.2**: boots, `wlan0` present. Works.
- On **crDroid 11**: **hangs at the Nothing logo.** crDroid loads its own `vendor_dlkm` kernel modules built for crDroid's `5.4.302`; DroidSpace's `5.4.289` kernel + crDroid's modules = vermagic mismatch → modules don't load → hang.

**Lesson:** a prebuilt custom kernel only works on the ROM/base it was built for. Kernel and `vendor_dlkm` modules must match.

## What actually works — crDroid 11 (Android 15) base

crDroid 11 for spacewar is Android 15, built on the NOS 3.2 base. Its kernel is `5.4.302-qgki`. Crucially, its config **already contains** the NetHunter essentials:

```
CONFIG_USB_CONFIGFS_F_HID=y   # USB HID gadget (BadUSB)
CONFIG_UHID=y                 # userspace HID
CONFIG_BT_HIDP=y              # Bluetooth HID
CONFIG_BT_BNEP=y              # Bluetooth network encap
CONFIG_BT_RFCOMM=y            # Bluetooth serial
CONFIG_CFG80211=y / CONFIG_MAC80211=y
CONFIG_MODULES=y / CONFIG_MODULE_UNLOAD=y
CONFIG_USB=y
```

So **crDroid 11's stock kernel is already NetHunter-capable for HID/BadUSB**, with working internal WiFi and touch. Installing the NetHunter chroot on top gives a functional NetHunter phone for USB-based attacks immediately. Bluetooth's protocol layers (`BT_HIDP`/`BT_BNEP`/`BT_RFCOMM`) are compiled in too, but — as covered above — the internal chip has no `hci0`, so BlueZ-based BT attacks need an external dongle. The only other thing missing is out-of-tree external-adapter WiFi drivers, which load as **modules**.

## The firmware migration that made it possible

Original state was crDroid 10 (Android 14 / NOS 2.6.0). To reach a working NetHunter kernel:

1. **Flash stock Nothing OS 3.2** (`Spacewar_V3.2-260206-1016`) full firmware — this sets the correct base and rebuilds `super` cleanly.
2. **Flash crDroid 11 (Android 15)** over it.
3. Root with Magisk; install NetHunter.

The stock-firmware flash from the Nothing Archive (spike0en) images, using the community Fastboot ROM flasher (delete/create/resize logical partitions), is the reliable way to fix a messed-up `super` partition. Custom recovery sideload was unreliable in testing; the fastboot flasher was dependable.

## Kernel rebuild gotcha — the "boots but no wlan0" trap

Rebuilding the kernel from the **bare** `vendor/lahaina-qgki_defconfig` produced a kernel that booted (correct `uname`, root worked) but had **no `wlan0`** — the in-kernel WiFi driver wasn't enabled the way crDroid enables it.

**Fix:** build from crDroid's **running** config (`/proc/config.gz` off a live crDroid 11 device) instead of the bare defconfig. That config already enables the built-in WiFi driver, touch, HID, and BT — everything. See `docs/BUILD.md` Option B.

## Toolchain note

crDroid's `build.config.common` pins **clang-r416183b (clang 12.0.x)**. Newer clang (18–22) throws hundreds of spurious errors on 5.4 code. Use the pinned version. The prebuilt package nests the binary at `clang-r416183b/clang-r416183b/bin/clang`.

## Boot image packaging note

crDroid's `boot.img`: header v3, **raw** (uncompressed) kernel, ramdisk `lz4_legacy`. To swap kernels with `magiskboot`:
- decompress your `Image.gz` → raw `Image`
- name it exactly `kernel`
- `magiskboot repack` — confirm `KERNEL_SZ` changes vs original (proof the swap happened)

## Environment gotcha

The kernel Makefile **refuses any build path containing a space or colon** (`source directory cannot contain spaces or colons`). Keep the whole build tree under a spaceless path like `~/kernel_build`.

## Summary decision tree

- Want HID / BadUSB? → crDroid 11 kernel already does it internally. Install NetHunter, done.
- Want Bluetooth attacks? → kernel protocol support (`BT_HIDP`/`BNEP`/`RFCOMM`) is present, but the internal chip has no `hci0` — **external USB BT dongle required** (CSR8510/RTL8761).
- Want WiFi injection? → **external adapter only**, over powered OTG. Internal is impossible.
- Want a custom-named kernel with the same features + module support? → rebuild from crDroid's running config (this repo).
- Flashing a prebuilt kernel? → it must match your exact ROM/base or it hangs.
