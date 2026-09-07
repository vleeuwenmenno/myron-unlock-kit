# Recovery readiness — 2026-09-07

## Conclusion

Follow-up research: see [hard-brick recovery options](HARD_BRICK_RECOVERY_OPTIONS.md)
for a myron-specific UFS repair report, EDL service leads and a concrete provider
inquiry. These leads have not yet been confirmed for our handset.

We have verified stock image files and working PC-to-Fastboot communication.
**We do not yet have a verified recovery route if ABL/EFI changes prevent both
Fastboot and recovery from starting.** Firmware files alone do not establish
permission or capability to restore them.

## What is available

The matching full recovery OTA contains boot-chain and OS partition payloads.
Ten images were extracted to ignored `research/run-recovery-stock/images/`:
boot, abl, init_boot, vendor_boot, recovery, dtbo, vbmeta, vbmeta_system, xbl, uefi.
Every extracted image passed the final SHA-256 check against its OTA payload
manifest; available operation hashes were checked too. Public checksums and sizes
are in `research/RECOVERY_IMAGE_MANIFEST.json`.

This is a recovery OTA ZIP, not a ready-to-run fastboot/EDL service package.
Its manifest does not contain efisp, misc, persist, userdata or a GPT image.
Its ZIP contains no EDL programmer or rawprogram/patch XML. OTA images are not
backups of this phone's unique data or of both live A/B slots. In particular,
the currently inactive slot need not match the running build.

## Non-flashing rehearsal performed

1. ADB reported locked=1, slot=_b and OS3.0.301.0.WPMEUXM.
2. Sent `adb reboot bootloader`.
3. `fastboot getvar product` returned myron.
4. Queried current-slot, unlocked, is-userspace and anti. All four printed
   FAILED/unsupported responses despite a host exit code of zero. Their values
   remain unknown through this interface. In particular, no rollback-index
   conclusion follows from the failed anti query.
5. `fastboot reboot` returned OKAY. ADB reconnected with the original build,
   slot and locked state. The user confirmed observing Fastboot and the reboot.

Raw results are in ignored `research/private/fastboot-rehearsal-20260907.json`.
No flashing, erasing, unlock, slot-switch, recovery wipe or EDL command was sent.
The first ADB read after reconnection had an empty sys.boot_completed property;
that read alone was not evidence that full Android startup had finished.
A subsequent check returned sys.boot_completed=1, locked=1 and SELinux Enforcing,
confirming Android finished starting after the rehearsal.

## Recovery matrix

| Failure state | Potential recovery | What is established here |
|---|---|---|
| Temporary-root process fails, Android still works, no persistent changes | End experiment; normal reboot may clear transient kernel modifications | Normal reboot works now; exploit-failure behavior not tested |
| OS fails, Fastboot survives and permits required writes | Restore exact affected stock partitions using a reviewed slot-specific procedure | Image files available; flashing authorization and actual restore not tested |
| OS fails, bootloader still locked | Stock recovery/vendor-approved signed restore, if accepted | Recovery interface, package acceptance and reinstall policy untested; arbitrary Fastboot flashing cannot be assumed |
| ABL/EFI failure removes Fastboot and recovery | Compatible EDL/service programming or hardware repair | No accepted loader, authentication capability, successful myron restore or service commitment established |
| Unique calibration/security/storage data damaged | Original device-specific backups, if restorable | OTA is not such a backup; none captured here |

[AOSP bootloader documentation](https://source.android.com/docs/core/architecture/bootloader/locking_unlocking)
describes locked-device flashing restrictions and additional critical-section
protection. This is architecture guidance, not a promise of particular Xiaomi
Fastboot commands. Do not turn OEM unlocking on/off or relock as a recovery test.

## What is missing for an ABL/EFI experiment

- A byte-level review of the exact July package and its ordered writes, including
  its handling of root failure, backup failure, unsupported variables and timeouts.
- Before any persistent writes, independently copied and hashed live backups of
  both ABL slots, efisp and every other partition the chosen script changes.
  Verify partition sizes, slot identity and rollback constraints. Do not assume
  a successful OTA extraction replaces these live backups.
- A way to restore those bytes after the failing component is unavailable.
  Requiring the same root exploit or damaged ABL to run is not an independent
  recovery route. Preserving an alternate slot helps only if fallback and shared
  partition effects are understood; writing both ABL slots removes that margin.
- A specifically confirmed service/EDL fallback for this model if local restore
  is unavailable. USB 9008 detection is not proof of storage programming access.

The [bkerler EDL project](https://github.com/bkerler/edl) documents loader
selection and authentication limitations. It does not establish a working myron
loader for us. [Android Root Tool's vendor page](https://androidroottool.com/download/)
lists myron among service models, but lacks the exact-build successful recovery
evidence needed here; this is a lead, not an endorsement or verified fallback.

Official contact path: [Xiaomi Netherlands support](https://www.mi.com/nl/support/)
or [POCO support contacts](https://www.po.co/global/support/contact/). No provider
has been contacted. A precise request would be:

> Can you restore stock firmware on POCO F8 Ultra 25102PCBEG (myron EEA) if an
> experimental bootloader modification leaves neither Fastboot nor recovery
> accessible? Does your service support this state through authorized EDL, or
> would it require board replacement? What are the cost and acceptance conditions?

Until this is resolved, describe the stock files as **prepared restoration
material**, not a guaranteed unbrick kit. No destructive trial is necessary to
prove that the current files and communication work.

## Reproducing stock-image preparation

`research/extract_boot.py` now accepts `--partition` for the ten partitions above;
boot remains its default. Repeat for each required partition, using the same
full OTA and output directory:

```sh
python3 research/extract_boot.py '/path/to/full-ota.zip' --partition abl --output-dir research/run-recovery-stock
```

Existing image output is refused. Save the per-partition extraction report and
independently hash the extracted file. Extraction does not flash anything.
