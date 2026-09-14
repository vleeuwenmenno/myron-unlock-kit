# Xiaomi8Elite5seriesBLunlock.zip — offline inspection

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

Date: 2026-09-07. User supplied archive, associated with the download linked by
the [DroidWin guide](https://droidwin.com/how-to-unlock-bootloader-on-poco-f8-ultra/).
The association is not independent authentication of the downloaded bytes.

## Identity and scope

- Archive: `Xiaomi8Elite5seriesBLunlock.zip`
- Size: 22,675,863 bytes
- SHA-256: `285c6e2e53463f57a6d39dbbb667018cd5eae9fa28e47478c58fad991c094c07`
- EFI payload: `unlock/gbl_efi_unlock.efi`, 40,960 bytes
- EFI SHA-256: `88918dd212fefe9d51c584513cbb7babebf395879d9edc2a02acd4246b5bcf5d`

Read all three batch scripts, the usage instructions and platform-tools metadata.
Inspected EFI PE headers and printable ASCII/UTF-16LE strings. Hashed every file
after ZIP decompression (which also checks ZIP CRCs). Saved the full inventory
and selected original files under ignored `research/private/xiaomi-unlock-package/`.
No included executable, DLL, batch script or EFI image was executed. No device
command was issued during this review. Bundled Windows binaries have not been
authenticated or fully audited; the EFI has not been fully reverse-engineered.

## What the scripts actually do

| Component | Observed behavior |
|---|---|
| `unlock1.bat` | Reboots to bootloader, invokes OEM `set-gpu-preemption-value` with an appended `androidboot.selinux=permissive` argument, then invokes fastboot continue. Attempts to delete itself. |
| `unlock2.bat` | Pushes the EFI payload into `/data/local/tmp`, calls transaction 21 of `miui.mqsas.IMQSNative` with arguments asking it to run dd into `/dev/block/by-name/efisp`, then reboots. Attempts to delete itself. |
| USB3 fix batch file | Writes three Windows HKLM USB registry values. It is unrelated to our Linux host and is not invoked by either unlock script. |

This is an attempted bootloader argument-injection / permissive-SELinux entry,
followed by an attempted privileged Xiaomi service command. It is **not
GhostLock**, and no GhostLock binary or target-offset table appears in the ZIP.
The precise vulnerable implementation and behavior on this firmware remain
unverified; the batch commands alone cannot establish successful exploitation.

Both unlock scripts lack model/build checks, success/error branching, partition
backups and post-write verification. The second script proceeds to reboot even
if the preceding push or service call fails. Their final command launches deletion
of the running batch file, so originals should be preserved for audit purposes.

The scripts do not themselves erase userdata or issue `fastboot erase efisp`;
those are separate manual instructions in the included text/guide. Do not
confuse them with steps already performed.

## Compatibility conclusion

The included instructions explicitly require a system security patch **before
February 2026** and name POCO F8 Ultra among the intended devices. Our stock
device reports `2026-04-01` on `OS3.0.301.0.WPMEUXM`, placing it outside the
package's stated compatibility window. That is a reason not to run this package
as-is, rather than proof of exactly which stage is patched.

Disabling updater/account/lock-screen features does not change that patch level
or demonstrate that the vulnerable behavior is present.

## EFI evidence and relationship to the other route

PE machine is `0xaa64` (AArch64); subsystem is 10 (EFI application). The PE
certificate-table directory is zero, so no embedded PE certificate table was
found. This does not establish whether a particular bootloader accepts the image.

Embedded strings identify `VbRwStateApp`, locating a `VerifiedBoot` protocol,
and read/write configuration operations. These are consistent with a payload
intended to alter verified-boot device state; strings alone do not prove its full
behavior or successful execution.

The previously reviewed myron script also writes a file named
`gbl_efi_unlock.efi` to `efisp`, after obtaining root through GhostLock. That is
a shared destination and apparent later-stage purpose. **Byte identity has not
been established**: that repository did not provide the external payload used
in its script. Nor does this archive validate GhostLock's borrowed physical
address or validate EFI compatibility on our April-patch firmware.

## Repeating this inspection

Use Python's `zipfile.ZipFile` to enumerate `infolist()`, and `read()` to inspect
only `.bat` and instruction text without executing them. Compute SHA-256 of the
archive and each uncompressed member with `hashlib.sha256`. Avoid blanket
extraction of an untrusted archive; the local inspection copied only explicitly
selected files under fixed basenames into an ignored directory.

For the EFI, read the PE offset at file offset 0x3c, verify the PE signature, and
inspect the COFF machine and optional-header subsystem/certificate directory.
ASCII and UTF-16LE strings provide leads, not behavioral verification. Keep any
future disassembly findings distinct from the limited header/string inspection
recorded here.

Outcome: useful evidence about an older entry route and the EFI stage, but not
a demonstrated compatible unlock procedure for the connected phone.
