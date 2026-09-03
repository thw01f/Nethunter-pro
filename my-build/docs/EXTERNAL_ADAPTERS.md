# External USB Adapters (WiFi injection + Bluetooth)

Two of this kernel's attack capabilities are hardware-gated on the phone's *internal* radios and require an external USB adapter instead:

- **WiFi monitor mode / injection** — internal WCN6750 firmware doesn't expose it.
- **Bluetooth attacks via BlueZ** — internal BT chip has no `hci0` (see below).

Both need a **powered OTG hub** — these adapters draw more than the phone comfortably supplies on its own.

## WiFi: adapters that just work (drivers already in this kernel / mainline)

| Adapter | Chipset | Driver | Notes |
|---|---|---|---|
| Alfa AWUS036NHA | Atheros AR9271 | `ath9k_htc` | 2.4 GHz only, in-kernel, most reliable |
| TP-Link TL-WN722N **v1 only** | AR9271 | `ath9k_htc` | v2/v3 are Realtek — avoid |
| Alfa AWUS036ACM | MediaTek MT7612U | `mt76x2u` | dual-band, mainline, great injection |

For these: plug in via OTG, then in the NetHunter chroot:

```bash
airmon-ng start wlan1
aireplay-ng --test wlan1mon        # "Injection is working!" = success
```

## WiFi: Realtek adapters (need a module built)

Adapters like the AWUS036ACH (RTL8812AU) use out-of-tree drivers not compiled into the kernel. Build the driver as a **loadable module** against this kernel.

### Build the module

On your build host (same toolchain/kernel tree as the kernel build):

```bash
cd ~/kernel_build
git clone https://github.com/aircrack-ng/rtl8812au
cd rtl8812au

# point it at the built kernel and cross toolchain
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export KSRC=~/kernel_build/crdroid_kernel/out

# set platform to ARM64/Android inside the driver Makefile
sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/' Makefile
sed -i 's/CONFIG_PLATFORM_ANDROID_ARM64 = n/CONFIG_PLATFORM_ANDROID_ARM64 = y/' Makefile

make -j$(nproc) KSRC=$KSRC
# produces 88XXau.ko
```

> The `.ko` must match this kernel's version/vermagic exactly. Build it against the same `out/` tree used to build the kernel you flashed.

### Load it on the phone

```bash
adb push 88XXau.ko /sdcard/Download/
adb shell "su -c 'insmod /sdcard/Download/88XXau.ko'"
adb shell "su -c 'dmesg | tail'"           # look for the driver registering
# plug adapter in; a wlan1 (or similar) should appear
adb shell "su -c 'ip link'"
```

If `insmod` complains about vermagic, rebuild the module against the exact kernel `out/` tree you flashed.

## WiFi reality check

- Monitor mode + injection on the **external** adapter is the supported path for all serious WiFi work on this phone.
- Nothing about the kernel or drivers unlocks **internal** injection — the WCN6750 firmware forbids it.

## Bluetooth: why the internal chip doesn't work with BlueZ

The Nothing Phone 1's Bluetooth radio is part of the same WCN6750 combo chip as WiFi, and it's wired up as a **UART-attached, HAL-bound** controller — the path Android's own Bluetooth stack (Fluoride) uses, not a standard HCI transport BlueZ can bind to.

Concretely:
- There is **no `hci0`** for the internal chip. `hciconfig` / `bluetoothctl list` show nothing.
- `hciattach qca` — the normal way to bring a Qualcomm UART Bluetooth chip up as an HCI device on Linux — is **not supported** on this device's UART wiring/firmware path. It does not produce a controller.
- The kernel's `CONFIG_BT_HIDP`, `CONFIG_BT_BNEP`, `CONFIG_BT_RFCOMM` are real and enabled — but they're protocol layers (HIDP, BNEP, RFCOMM sockets) that run *on top of* an HCI controller. With no `hci0`, there's nothing for them to bind to. Kernel config presence is necessary but not sufficient.

**Consequence:** BlueZ-based attacks (bluetoothctl, hcitool, BlueDucky, etc.) need a controller to drive. Use an external USB Bluetooth dongle.

### Adapters that work

| Adapter chipset | Driver | Notes |
|---|---|---|
| CSR8510 (CSR/Qualcomm) | `btusb` (in-kernel) | Cheap, extremely common, plug-and-play |
| RTL8761 (Realtek) | `btusb` (in-kernel) | Dual-mode BT, widely available |

Plug in via OTG, then verify a controller appears:

```bash
hciconfig -a          # should list hci0 (the external dongle)
bluetoothctl list      # should show the dongle's controller
```

From there, standard NetHunter/Kali BT tooling (bluetoothctl, hcitool, BlueDucky, etc.) works against `hci0` normally — the same as on a laptop.

## Reality check — hardware-gated capabilities, summarized

- **WiFi injection**: external adapter only. Internal WCN6750 firmware forbids monitor mode.
- **Bluetooth attacks (BlueZ)**: external dongle only. Internal chip has no `hci0`; it's reserved for Android's own Bluetooth HAL.
- Neither limitation is fixable by rebuilding the kernel — both are firmware/wiring-level, not driver-level.
