# Successful device record — 2026-09-08

> **Disclaimer — research use only; use at your own risk.** This independent
> project is not affiliated with, endorsed by, or sponsored by Xiaomi, Redmi,
> or POCO. These materials are intended for research and educational purposes
> only, on devices you own or are explicitly authorized to test. Using the
> tools or following the procedures can permanently brick your device, erase
> or corrupt all data, weaken security, and cause loss of functionality or
> access to updates and services. Recovery is not guaranteed.
> The author, maintainers, and contributors provide everything **as is, without
> warranty**, and accept no responsibility or liability for damage, data loss,
> costs, or other consequences, to the fullest extent permitted by applicable
> law. You are responsible for your actions and backups. Past success does not
> guarantee safety or compatibility. Read the [full disclaimer](../DISCLAIMER.md)
> before using any material in this project.

## Starting state

- POCO F8 Ultra EEA, model `25102PCBEG`, codename `myron`
- `OS3.0.301.0.WPMEUXM`, Android security patch 2026-04-01
- Kernel `6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k`
- Slot `_b`, bootloader locked, verified boot green
- Native inactive slot A contained older `OS3.0.2.0.WPMEUXM` components

## Observed successful sequence

1. Exact-target GhostLock obtained `uid=0(root)` with context
   `u:r:kernel:s0`; SELinux became permissive.
2. Fifty-seven boot-chain and unique partitions were backed up and verified.
3. First and last 1 MiB of UFS LUNs `sda` through `sdf` were backed up and
   verified, preserving both GPT copies and slot attributes.
4. Unlock EFI was staged to `efisp`; full partition SHA-256 was
   `823bfe06165e570c9d6abdf518a09edb032676e9cbc8cf708d85aa3cbedeb3f4`.
5. Android BootControl AIDL HAL version 3 changed next active slot from B to A.
   Readback showed `current=1 active=0`, A bootable and not successful, B
   bootable and successful.
6. Reboot to bootloader used native signed slot-A ABL. Raw Fastboot returned
   `unlocked=yes`.
7. Raw Fastboot selected slot B and read back `current-slot=b`.
8. Raw Fastboot erased `efisp` and returned `OKAY`.
9. Stock recovery requested the expected userdata wipe for the first unlocked
   boot.

No ABL, XBL, boot, vbmeta, recovery, FRP, misc, or Android system partition was
flashed or erased during the unlock. The only boot partition content write was
the temporary EFI in `efisp`, followed by its erase.

## Key artifact hashes

- GhostLock binary:
  `802f1c011ed39b7517a36806ac38b7b280c11fd3552ac9a6dc8d0429b2b3e57b`
- Unlock EFI:
  `88918dd212fefe9d51c584513cbb7babebf395879d9edc2a02acd4246b5bcf5d`
- Read-only probe EFI:
  `08ad10ab574fe183f5d7f764ad11879b436191ce5e8d3710e6de415dd12c00eb`
- Android BootControl helper:
  `99ce20a270b876ecbc780531bdbdeb70ebe57fa921ad0b0d80b9bb02ae820503`
- Generic host raw-Fastboot helper: see the kit integrity manifest for its
  current hash. It requires `MYRON_FASTBOOT_SERIAL` and verifies that value
  against the connected USB device before sending a command.
- Native inactive `abl_a` full partition:
  `dce32572f3740ed058cd033f40b2009ef6b241170a913aba0b2714178498d8db`
- Original empty `efisp`:
  `bbd05cf6097ac9b1f89ea29d2542c1b7b67ee46848393895f5a9e43fa1f621e5`

The verified device-specific backup is stored separately from this reusable
kit. Its combined archive SHA-256 is:

`6e84cf43798c98d1c0715ec081ae97ac2ce3154eb47b455d3aa5cdbebe7097b2`
