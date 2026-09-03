# NetHunter Pro — Nothing Phone (1) / "spacewar"

This repository collects the pieces needed to build and run **Kali NetHunter**
on the **Nothing Phone (1)** (codename `spacewar`, Qualcomm SM7325 /
Snapdragon 778G+): the upstream kernel/image tooling this work builds on, and
`my-build/`, containing the NetHunter kernel build scripts, docs, and findings
for this specific device.

Maintainer of this repo and `my-build/`: **w01f (thw01f)**

---

## Folder structure

- **`kali-pinephone/`** — upstream reference tooling, unmodified. See CREDITS below.
- **`spacewar_tweaks/`** — upstream kernel patches/configs for the `spacewar`
  device, unmodified. See CREDITS below.
- **`my-build/`** — this project's own kernel build scripts, install/build docs,
  and findings for bringing NetHunter up on the Nothing Phone (1).

---

## CREDITS / ATTRIBUTION

`kali-pinephone/` and `spacewar_tweaks/` are **not my work**. They are included
here, unmodified, for reference and archival purposes so this project's build
instructions have a stable copy of the tooling and patches they depend on.
**All credit for the code in those two folders goes to the original author,
Shubhamvis98.**

- Original repo: [kali-pinephone](https://github.com/Shubhamvis98/kali-pinephone)
- Original repo: [spacewar_tweaks](https://github.com/Shubhamvis98/spacewar_tweaks)

See the `NOTICE` file inside each folder for the same attribution statement.

### Licensing of the included upstream folders

Neither `kali-pinephone` nor `spacewar_tweaks` contains a `LICENSE` file in
the upstream repository as of the date these copies were made. **No license
is asserted or invented on their behalf here.** They are included as-is,
with full credit and copyright remaining with the original author,
Shubhamvis98. If you intend to redistribute or build on this code, check the
original repositories directly for any license terms the author may add.

### Licensing of `my-build/`

See `my-build/LICENSE` for the license covering this project's own kernel
build scripts and documentation.

---

## ⚠️ WARNING

- **Flashing wipes data.** Back up everything before touching the bootloader,
  boot partition, or userdata.
- **Firmware downgrades can trip anti-rollback protection and hard-brick the
  device.** Do not flash an older firmware/bootloader than what is currently
  on the device unless you fully understand the anti-rollback fuses on this
  SoC.
- **Default NetHunter login is `kali` / `8888`.** Change it after first boot.

Proceed at your own risk. This is unofficial, community-driven work with no
warranty of any kind.


---

## Getting started

See `my-build/README.md` and `my-build/docs/` (`BUILD.md`, `INSTALL.md`,
`FINDINGS.md`, `EXTERNAL_ADAPTERS.md`) for build and install instructions
specific to this device.
