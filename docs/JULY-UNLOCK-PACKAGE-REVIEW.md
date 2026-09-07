# July unlock package review — 2026-09-07

Status: inspected offline only. Do not execute this package on the tested EEA
OS3.0.301.0.WPMEUXM kernel. No root attempt, partition write or unlock occurred.

## Provenance

Exact July 22 XDA-linked archive:
https://drive.google.com/file/d/1V658pVGZ1J2cOAOuJm3Ta7THYIoCJ2fh/view

Thread:
https://xdaforums.com/t/free-xiaomi-17-series-redmi-k90-pro-max-bootloader-unlock-no-disassembly.4781471/

Archive SHA256: `892ca27cda200b0836e293f60f21832c56c8b050dbcaad2935b7654432203feb`.
Public password Unlock; inspected nested 7z contents without executing them.
Per-file hashes are in JULY_PACKAGE_MANIFEST.json. Hashes identify the downloaded
artifacts; they do not authenticate their author or establish safety.

This is different from Linuxoid-cn's GitHub v2 release:
https://github.com/Linuxoid-cn/Mi8E5-Unlocker-by-CVE-2026-43499/releases/tag/v2.0.0
The latter ZIP SHA256 is
`5a7e9589c54f0f92d7aeff5f3a8a1d1d3b325ec9447f161be2717e9fbb229f66`.
Do not transfer review conclusions between these packages.

## Concrete kernel mismatch in July preload.so

SHA256: `182a4d8e11cca6db44e091106ca5502182ea7da7aa11bb2005839294822ef4cc`.
Offline AArch64 disassembly with Capstone and ELF symbol/PLT relocation inspection
shows fixed addresses passed to canon_addr in run_exploit. canon_addr adds
0x3f80000000 and a runtime base; it does not independently discover each symbol.
The table compares the binary's fixed addresses with stock kallsyms recovered
from our verified full-OTA kernel (nominal _text = ffffffc080000000).

| Intended target inferred from use | July constant | Stock symbol | Difference |
|---|---|---|---|
| per-CPU offsets | ffffffc0823eb810 | __per_cpu_offset: ffffffc0823db810 | +0x10000 |
| root credentials | ffffffc082412a68 | init_cred: ffffffc082402a68 | +0x10000 |
| SELinux state | ffffffc08267a5b8 | selinux_state: ffffffc0826684f0 | +0x120c8 |

Instruction sites: f3cc–f3d8, f65c–f668, f760–f76c respectively.
The relocation for PLT 0x14c90 resolves to canon_addr. Root credential writes use
that derived pointer at task offsets 0x8f8 and 0x900; PLT 0x14ce0 and 0x14cf0
resolve to direct_pselect_write_once and direct_pselect_write_followup_once.
Those task offsets agree with our BTF checks, but the symbol addresses do not.
The unequal differences mean a uniform image-base or _text/_stext adjustment
cannot reconcile all three. This is evidence against using this binary as-is,
not a complete reverse-engineering proof or a proposal to patch three constants.
Other gadget, structure, stack and physical-address assumptions need review too.

Selected disassembly is retained privately under
research/private/july-unlock/selected-disassembly.txt. Binary contains embedded
su and daemon installation functionality; calling it a read-only probe would be
incorrect. Exact matching source revision has not been established.

## July Windows wrapper

Line numbers refer to decoded Unlocking(一键解锁).bat, gb18030.

- Manual model selection; no automatic exact firmware/kernel validation.
- Lines 91–108 push replacement ABL and preload, then invoke preload using
  LD_PRELOAD and /system/bin/true. This executes the exploit, despite true's name.
- Line 111 tests su id output. Lines 125/127 immediately overwrite BOTH abl_a
  and abl_b. No live partition backup precedes these writes.
- Line 131 writes EFI to efisp. No readback hash verification or original backup.
- Line 203 searches getvar unlocked output for yes; failed checks can loop back.
- Lines 215–217 erase frp, flash misc_wipe.img and erase efisp.
- No original ABL restoration exists in this script. Partition command failures
  are not consistently checked. Relative paths depend on the working directory.

K90ProMax replacement ABL SHA256:
`f0d10ca6bf9be5da39bd97005a0f6d2bbd913db3c6783d923f961024caa46878`.
This is not our stock ABL (see RECOVERY_IMAGE_MANIFEST.json).
EFI SHA256 `88918dd212fefe9d51c584513cbb7babebf395879d9edc2a02acd4246b5bcf5d`
is identical to the old March ZIP payload. The shared EFI does not make the
new root method compatible with our firmware.

Linuxoid v2 separately attempts ABL backup/restoration but does not reliably
abort on backup/write failures, uses unquoted backup paths and deletes all
/data/local/tmp contents. Its safeguards do not exist in the exact July wrapper.

## Next work

Do not run either one-click wrapper. A usable route needs a source-auditable
root stage matched to the exact stock kernel, followed by verified live backups
and separately reviewed bootloader operations. The previously examined Taiwan
source target has matching relative offsets, but its physical-address and
runtime-chain assumptions remain unresolved (TEMP_ROOT_REVIEW.md).
Stock OTA images and a successful Fastboot rehearsal do not establish recovery
if the replacement bootloader prevents Fastboot from starting.
