# Myron TWRP recovery installation

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

This procedure is pinned to the tested POCO F8 Ultra EEA handset:

- codename `myron`, model `25102PCBEG`
- HyperOS `OS3.0.301.0.WPMEUXM`
- Android security patch `2026-04-01`
- active Android slot `_b`
- unlocked bootloader (`ro.boot.flash.locked=0`)

It installs the Myron image from the upstream
[TWRP device tree](https://github.com/MissMyTime/twrp_device_sm8850), release
[1.4](https://github.com/MissMyTime/twrp_device_sm8850/releases/tag/1.4).
The upstream Myron notes identify it as an A/B recovery image with no embedded
kernel, so it is flashed to the recovery partition and is not suitable for
`fastboot boot`.

## Reviewed files

| File | Bytes | SHA-256 |
|---|---:|---|
| `TWRP_myron_finix_20260809.img` | 104857600 | `c963f75c3a51666db2a92d3b50f79f9fd4bf320cdef93ca45de9ab0ef27a6a53` |
| Exact EEA stock `recovery_b.img` | 104857600 | `bfb8e0c2fa2e7c974e8ae5ca65cc80e0d60dd24076c61abae1445fff2788825d` |

The TWRP hash matches the digest published with release 1.4. The stock hash is
from the device-specific boot-chain backup and matches the recovery image
extracted from the exact EEA full OTA.

The image was unpacked before use. It is an Android boot-header-v4 ramdisk-only
recovery with an unsigned AVB footer for partition `recovery`. The included
Myron fstab, root ADB configuration, fastbootd support, MTP configuration and
touch resources are present. Its fallback kernel modules were built for a
different Myron kernel revision, so this test relies on the active slot's exact
kernel and vendor modules rather than assuming those fallback modules load.

An older alternative named
`EFISP_TWRP_myron_v13base_OTG_flashfix_20260807.img` was also reviewed. It is a
104857600-byte Android boot image with SHA-256
`12133d11b8fb747bf105f70c828617632034c82cabc41cdeb23135b08a0f5280`.
Its unpacked ramdisk contains the same Myron NXP decryption gate as release 1.4,
while release 1.4 is the later build and adds recovery/Persist handling. It was
not flashed because it offers no decryption advantage over the working image.

## Why the procedure does not use standard Fastboot

Two ordinary Fastboot attempts were made while the unlocked phone was in its
bootloader:

```text
fastboot --slot=b flash recovery ...
FAILED: Device does not support slots

fastboot flash recovery_b TWRP_myron_finix_20260809.img
Warning: recovery_b partition size: 0
FAILED (remote: ' Invalid argument size')
```

The second command failed during the image download and did not write the
partition. Retrying after a bootloader restart produced the same result. The
live partition remained stock.

## Stage and verify the inputs

Keep the recovery images outside this public repository. From the repository
root, replace the two host paths below with the reviewed TWRP image and the
exact stock `recovery_b.img` from this phone's backup:

```bash
adb push /path/to/TWRP_myron_finix_20260809.img \
  /data/local/tmp/TWRP_myron_finix_20260809.img
adb push /path/to/recovery_b.img \
  /data/local/tmp/recovery_b-stock-OS3.0.301.0.WPMEUXM.img
adb push tools/myron-install-twrp-recovery.sh \
  /data/local/tmp/myron-install-twrp-recovery.sh
adb push tools/myron-restore-stock-recovery.sh \
  /data/local/tmp/myron-restore-stock-recovery.sh
adb shell chmod 755 /data/local/tmp/myron-install-twrp-recovery.sh
adb shell chmod 755 /data/local/tmp/myron-restore-stock-recovery.sh
adb shell sha256sum /data/local/tmp/TWRP_myron_finix_20260809.img
adb shell sha256sum \
  /data/local/tmp/recovery_b-stock-OS3.0.301.0.WPMEUXM.img
```

Both hashes must match the table above.

## Install TWRP

Run the temporary-root wrapper in your own interactive terminal:

```bash
cd ~/Projects/myron-unlock-kit
./root-exploit/root-shell.sh --expect-unlocked
```

Press `Y` and wait for the root prompt. The exploit is a timing race and may
take several minutes. At `myron:/ #`, run:

```sh
/data/local/tmp/myron-install-twrp-recovery.sh
```

The script refuses to write unless the device, build, patch, bootloader state,
slot, file sizes, input hashes, block-device path and live stock recovery hash
all match. It writes only `recovery_b`, then hashes the entire live partition.
If that readback is wrong, it automatically rewrites the exact stock image and
verifies that restore.

Required success line:

```text
TWRP recovery_b write and full-partition readback verified: c963f75c3a51666db2a92d3b50f79f9fd4bf320cdef93ca45de9ab0ef27a6a53
```

### Observed result on 2026-09-08

The tested handset passed the live-stock hash gate, wrote all 25 4 MiB blocks
(`104857600` bytes), and returned the required full-partition TWRP hash above.
No other partition was written. Release 1.4 then booted successfully from
`recovery_b`; its display, touch input, English UI and root ADB all worked.

Type `exit`. Wait until the wrapper reports that Android is boot-complete and
SELinux is Enforcing, then boot recovery:

```bash
adb reboot recovery
```

Validate the TWRP title/version, touch input and root ADB before using any wipe
or flash operation:

```bash
adb devices
adb shell id
adb shell getprop ro.product.device
```

### Decrypting Data

Configure a PIN in Android before entering recovery. On this tested EEA build,
Android's no-lock-screen protector was not usable by TWRP: recovery could mount
the metadata-encrypted block device, but could not find the expected password
record and displayed encrypted filenames under `/data/media/0`.

After a PIN was configured in Android and the phone rebooted into the same
release 1.4 recovery, TWRP prompted for that PIN and decrypted Data. This did
not require changing or reflashing the recovery image. The successful recovery
log reported:

```text
password type: PIN
Weaver AIDL getConfig OK on attempt 1 slots=64 keySize=16 valueSize=16
User 0 Decrypted Successfully!
Data successfully decrypted
```

The result was independently checked over ADB:

```bash
adb shell getprop twrp.user.0.decrypt
# 1
adb shell df -h /data
adb shell ls -la /data/media/0
```

`/data/media/0` then exposed normal names including `DCIM`, `Documents`,
`Download`, `MIUI` and `TWRP`. The NXP StrongBox service remained stopped; the
working path used the running NXP Weaver service. Do not format Data to address
the no-credential case—set a PIN in the booted Android system and retry first.

## Restore exact stock recovery

Boot Android normally and start the same unlocked-state temporary-root shell.
At its root prompt run:

```sh
/data/local/tmp/myron-restore-stock-recovery.sh
```

This inverse script requires the live partition to match the reviewed TWRP
hash before it writes, restores the exact stock image, and verifies the entire
partition. If the stock readback fails, it attempts to restore and verify TWRP.
After its success line, type `exit` and let the wrapper return Android to
boot-complete, SELinux-Enforcing state.

Neither script changes `boot`, `init_boot`, `vendor_boot`, `vbmeta`, the active
slot, userdata, GPT, ABL, or `efisp`.
