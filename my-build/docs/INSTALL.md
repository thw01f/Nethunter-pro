# Installing the NetHunter Kernel — Nothing Phone (1) Spacewar

**Read the whole thing before starting.** Flashing carries bootloop/data-loss risk. Keep the stock NOS 3.2 firmware package on hand as a recovery path.

## Prerequisites

- Nothing Phone (1) `spacewar`, **bootloader unlocked**
- **crDroid 11 (Android 15)** already installed and booting
  - crDroid 11 requires the **Nothing OS 3.2** firmware base. If you're not on it, flash NOS 3.2 first (see the main README / Nothing Archive).
- **Magisk** installed (get it from https://github.com/topjohnwu/Magisk — official only)
- `adb` + `fastboot` on your computer (Android platform-tools)
- USB cable, and the phone's USB debugging enabled

## Files you need

- `boot-nethunter.img` — from this repo's [Releases](../../releases)
- Your **crDroid 11 `boot.img`** (for reference/recovery) — extract from the crDroid ROM zip's `payload.bin` with `payload_dumper`

## Step 1 — Get the kernel onto your computer

Download `boot-nethunter.img` from Releases.

## Step 2 — Root it (patch with Magisk)

You want kernel + root together. Push the image to the phone and patch it:

```bash
adb push boot-nethunter.img /sdcard/Download/boot-nethunter.img
```

On the phone: **Magisk app → Install → Select and Patch a File → `Download/boot-nethunter.img` → Let's Go.**

Pull the patched result back (the suffix is random):

```bash
adb shell ls /sdcard/Download/magisk_patched*
adb pull /sdcard/Download/magisk_patched-XXXXX.img .
```

## Step 3 — TEST non-destructively (do NOT skip)

`fastboot boot` runs the image from RAM without writing it — if anything's wrong, a reboot fully recovers you.

```bash
adb reboot bootloader
fastboot getvar current-slot        # note your slot (usually a)
fastboot boot magisk_patched-XXXXX.img
```

Wait 2–4 minutes for boot, then verify **everything**:

```bash
adb shell "uname -a"                # should show this kernel + your build date
adb shell "su -c id"                # uid=0 → root works (tap Grant on phone)
adb shell "ip link | grep wlan"     # wlan0 present → internal wifi ok
```

Then on the phone itself:
- **Touch works?**
- **Connect to a WiFi network** → does internet work?
- UI responsive?

### Decision
- ✅ Boots, `wlan0` present, touch + root + wifi all work → **go to Step 4**
- ❌ Bootloop / no `wlan0` / dead touch → recover: hold **Power + Volume Down** to force the bootloader, then `fastboot reboot` to return to your working crDroid. Nothing was flashed. Report the issue on the repo.

## Step 4 — Flash permanently

Only after Step 3 passes:

```bash
adb reboot bootloader
fastboot flash boot magisk_patched-XXXXX.img
fastboot reboot
```

(If your device is A/B and you want to be explicit: `fastboot flash boot_a ...` for slot a.)

## Step 5 — Install NetHunter (app + chroot)

The kernel provides the capabilities; the NetHunter app + chroot provide the tools.

1. Install the **NetHunter Store**: https://store.nethunter.com/NetHunterStore.apk
   ```bash
   adb install NetHunterStore.apk
   ```
2. Open the store → install the **NetHunter** app.
3. NetHunter app → **Chroot Manager → Install Chroot → Full**. Let it download and set up (~2 GB).

> Do **not** flash the generic NetHunter kernel zip on top — this kernel already provides the NetHunter features. Flashing another kernel will replace this one.

## Step 6 — Verify the attack features

**USB HID / BadUSB:**
- NetHunter app → **USB Arsenal** → configure a HID/keyboard attack → plug phone into a target computer → run. Kernel supports `F_HID` + `UHID`.

**Bluetooth attacks (needs external dongle):**
- Kernel supports `BT_HIDP`, `BT_BNEP`, `BT_RFCOMM`, but the **internal** BT chip has no `hci0` — it's UART/HAL-bound for Android's own Bluetooth stack, and `hciattach qca` doesn't work here. BlueZ tooling (bluetoothctl, hcitool, BlueDucky, etc.) has nothing to bind to internally.
- Plug in a CSR8510 or RTL8761 USB BT dongle (in-kernel `btusb`) → `hciconfig -a` should show `hci0` → use NetHunter/Kali BT tooling against it normally. See `docs/EXTERNAL_ADAPTERS.md`.

**WiFi injection (needs external adapter):**
- Internal WCN6750 **cannot** do monitor mode/injection — hardware limitation.
- Use an external adapter (Alfa AWUS036ACM / AWUS036NHA) via a powered OTG hub.
- ath9k_htc (AR9271) and mt7612u drivers are mainline; Realtek adapters need the driver built as a module (see `docs/EXTERNAL_ADAPTERS.md`).

## Recovery

If you ever need to revert to stock crDroid kernel:

```bash
adb reboot bootloader
fastboot flash boot <your-crdroid-boot.img>   # or a Magisk-patched crDroid boot
fastboot reboot
```

Keep the full **NOS 3.2 fastboot firmware** package as the ultimate recovery path (rebuilds every partition).
