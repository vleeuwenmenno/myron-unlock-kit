# POCO F8 Ultra EEA unlock kit — exact successful path

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
> guarantee safety or compatibility. Read the [full disclaimer](DISCLAIMER.md)
> before using any material in this project.

This kit records the path that unlocked one POCO F8 Ultra EEA on 2026-09-08
without replacing either ABL partition. It is intentionally pinned to the tested
firmware and kernel.

## Verified target

- Product: POCO F8 Ultra / Redmi K90 Pro Max family
- Model: `25102PCBEG`
- Device codename: `myron`
- Region/build: `OS3.0.301.0.WPMEUXM`
- Kernel: `6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k`
- Running slot before unlock: `_b`
- Required native inactive slot-A ABL SHA-256:
  `dce32572f3740ed058cd033f40b2009ef6b241170a913aba0b2714178498d8db`
- Required original empty `efisp` SHA-256:
  `bbd05cf6097ac9b1f89ea29d2542c1b7b67ee46848393895f5a9e43fa1f621e5`

The inactive slot on the tested phone contained the older
`OS3.0.2.0.WPMEUXM` boot chain. Its native signed ABL contains the unsigned
`efisp` loader needed by the EFI stage. The current slot-B ABL does not.

Do not use the binaries on a different build or kernel. A second phone needs
its own read-only backup. Never flash one phone's `persist`, `fsg`, modem state,
keystore, GPT, or other device-unique backup onto another phone.

## What this procedure changes

1. GhostLock temporarily disables SELinux enforcement and gives one Android
   shell process UID 0. This state disappears on reboot.
2. The unlock EFI is written to the otherwise empty 3 MiB `efisp` partition.
3. Android's official BootControl HAL selects the stock inactive slot A.
4. Native slot-A ABL runs the EFI, which changes the RPMB-backed bootloader
   lock state.
5. Unlocked Fastboot reselects slot B and erases `efisp`.
6. Stock recovery wipes userdata before the first normal unlocked boot.

Neither `abl_a` nor `abl_b` is written. The third-party replacement ABLs from
the one-click packages are not part of this kit.

## Host requirements

- Linux x86-64
- `adb` and `fastboot`
- C compiler, `pkg-config`, and libusb 1.0 development files
- Android NDK r27d or a compatible NDK with API 35 for rebuilding Android tools
- A direct, stable USB connection
- Battery above 50%
- USB debugging authorized; enable OEM unlocking in Developer options if shown

Verify the kit before using it:

```bash
cd myron-unlock-kit-20260908
sha256sum -c SHA256SUMS
```

Set the connected phone's ADB/Fastboot serial once. Replace the example value
with the value printed by `adb devices`:

```bash
PHONE_SERIAL=REPLACE_WITH_YOUR_SERIAL
export MYRON_FASTBOOT_SERIAL="$PHONE_SERIAL"
```

Optional reproducibility checks:

```bash
./tools/test-root-exploit.sh
./tools/build-root-exploit.sh /absolute/path/to/android-ndk-r27d
./tools/build-host-fastboot-raw.sh
./tools/build-android-bootctl.sh /absolute/path/to/android-ndk-r27d "$PHONE_SERIAL"
```

The root build helper uses a temporary symlink because the upstream Makefile
cannot parse an NDK path containing spaces.

## 1. Verify the phone

```bash
adb devices
adb shell getprop ro.product.model
adb shell getprop ro.product.device
adb shell getprop ro.build.version.incremental
adb shell uname -r
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.boot.flash.locked
```

The outputs must match the target above, with slot `_b` and lock value `1`.

The supplied raw-Fastboot helper reads the required serial from
`MYRON_FASTBOOT_SERIAL` and refuses any connected phone with a different
serial. You can reproducibly rebuild the generic helper with:

```bash
./tools/build-host-fastboot-raw.sh
```

## 2. Start temporary root

In terminal 1:

```bash
cd root-exploit
./root-shell.sh
```

The exploit is a race and can take several minutes or reboot the phone. A
successful prompt must show:

```text
uid=0(root) gid=0(root) context=u:r:kernel:s0
```

Keep this root shell open. Use terminal 2 for ordinary ADB commands.

## 3. Push the remaining tools

From the kit root in terminal 2:

```bash
./tools/push-device-tools.sh "$PHONE_SERIAL"
```

## 4. Make a device-specific recovery backup

In the root shell:

```sh
/system/bin/sh /data/local/tmp/myron-readonly-bootchain-backup.sh
```

Record the printed `BACKUP_DIR`. Then capture all GPT headers and UFS LUN
edges, substituting that exact directory:

```sh
/system/bin/sh /data/local/tmp/myron-readonly-gpt-backup.sh \
  /data/local/tmp/myron-bootchain-backup-YYYYMMDD-HHMMSS
```

In terminal 2, pull it and verify both manifests:

```bash
adb -s "$PHONE_SERIAL" pull \
  /data/local/tmp/myron-bootchain-backup-YYYYMMDD-HHMMSS ./device-backup/
BACKUP=./device-backup/myron-bootchain-backup-YYYYMMDD-HHMMSS
(cd "$BACKUP" && sha256sum -c SHA256SUMS)
(cd "$BACKUP/gpt-edges" && sha256sum -c GPT_SHA256SUMS)
./tools/verify-target-backup.sh "$BACKUP"
tar --zstd -cf myron-device-backup-YYYYMMDD-HHMMSS.tar.zst \
  -C device-backup myron-bootchain-backup-YYYYMMDD-HHMMSS
sha256sum myron-device-backup-YYYYMMDD-HHMMSS.tar.zst \
  > myron-device-backup-YYYYMMDD-HHMMSS.tar.zst.sha256
```

Copy that archive and checksum to separate secure storage before continuing.

## 5. Stage the unlock EFI

The script accepts either the original empty `efisp` or the supplied read-only
probe as its starting state. In the root shell:

```sh
/system/bin/sh /data/local/tmp/myron-stage-unlock-efi.sh \
  /data/local/tmp/myron-bootchain-backup-YYYYMMDD-HHMMSS \
  /data/local/tmp/myron-gbl-readonly-probe.efi \
  /data/local/tmp/myron-unlock.efi
```

Required final line:

```text
efisp SHA256: 823bfe06165e570c9d6abdf518a09edb032676e9cbc8cf708d85aa3cbedeb3f4
```

## 6. Select native slot A through Android

The exploit must still be running so SELinux reports `Permissive`. Run these in
terminal 2, through the ordinary ADB shell. Do not run the HAL helper inside the
`u:r:kernel:s0` root process; servicemanager does not return the HAL to that
domain.

```bash
adb -s "$PHONE_SERIAL" shell getenforce
adb -s "$PHONE_SERIAL" shell /data/local/tmp/myron-bootctl inspect
adb -s "$PHONE_SERIAL" shell /data/local/tmp/myron-bootctl \
  set-active-a I_UNDERSTAND_SET_ACTIVE_A
```

Required post-state:

```text
current=1 active=0
slot=0 suffix=_a bootable=yes successful=no
slot=1 suffix=_b bootable=yes successful=yes
```

To abort before reboot, run:

```bash
adb -s "$PHONE_SERIAL" shell /data/local/tmp/myron-bootctl \
  set-active-b I_UNDERSTAND_SET_ACTIVE_B
```

## 7. Trigger the EFI and verify unlock

This reboot ends temporary root:

```bash
adb -s "$PHONE_SERIAL" reboot bootloader
```

When Fastboot appears:

```bash
./tools/bin/myron-fastboot-raw get-unlocked
```

The successful tested result was:

```text
OKAYyes
```

If it says `OKAYno`, do not erase anything. Slot B is still marked successful;
allow the A/B retry mechanism to fall back to B. Do not flash a replacement
ABL as a recovery attempt.

## 8. Restore slot B and remove the EFI

After `OKAYyes`:

```bash
./tools/bin/myron-fastboot-raw set-active-b I_UNDERSTAND_SET_ACTIVE_B
./tools/bin/myron-fastboot-raw get-current-slot
```

The required slot result is `OKAYb`. A transient `LIBUSB_ERROR_IO` can occur
during USB re-enumeration; wait for Fastboot to return and retry the read-only
query.

Remove the EFI payload:

```bash
./tools/bin/myron-fastboot-raw erase-efisp I_UNDERSTAND_ERASE_EFISP
```

Required result: `OKAY`.

Reboot normally:

```bash
./tools/bin/myron-fastboot-raw reboot-system I_UNDERSTAND_REBOOT
```

The reboot command can report a USB I/O error because successful reboot drops
the Fastboot USB connection immediately.

## 9. Complete the mandatory data wipe

Stock recovery may show `Reboot`, `Wipe Data`, `Connect with MiAssistant`, and
`Restore system`. Select:

1. **Wipe Data**
2. **Wipe All Data**
3. Confirm
4. **Reboot** → **Reboot to System**

Do not choose Restore system or MiAssistant for this step.

## 10. Verify the unlocked normal boot

After Android setup and USB-debugging authorization:

```bash
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.verifiedbootstate
adb reboot bootloader
./tools/bin/myron-fastboot-raw get-unlocked
```

Expected values are `_b`, `0`, `orange`, and `OKAYyes`.

## Relocking

Do not relock while any custom boot, vbmeta, recovery, kernel, or system image is
installed. Restore a complete matching stock firmware first and verify that
`efisp` is empty. Relocking normally wipes userdata and can hard-brick a device
whose verified partitions do not match the trusted stock chain.

## Contents

- `root-exploit/`: exact-target auditable GhostLock source, tests, wrapper, and
  the binary used for the successful run.
- `tools/`: read-only backup scripts, guarded staging scripts, build scripts,
  and verification helpers.
- `tools/bin/`: prebuilt host raw-Fastboot client and Android BootControl helper.
- `tools/source/`: source for both helpers.
- `payloads/`: the reviewed unlock EFI and optional read-only probe.
- `docs/SUCCESS-RECORD.md`: hashes and observed results from the successful run.
- `docs/JULY-UNLOCK-PACKAGE-REVIEW.md` and
  `docs/XIAOMI-UNLOCK-PACKAGE-REVIEW.md`: audits explaining why replacement
  ABL payloads were excluded.
- `docs/RECOVERY-PLAN.md` and `docs/HARD-BRICK-RECOVERY-OPTIONS.md`: recovery
  references to read before modifying boot partitions.
- `SHA256SUMS`: integrity manifest for every other file in this kit.
