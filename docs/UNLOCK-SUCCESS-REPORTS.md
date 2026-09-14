# Unlock success evidence — checked 2026-09-07

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

Target: POCO F8 Ultra myron EEA, `OS3.0.301.0.WPMEUXM.C07`, April 1 security
patch, kernel `6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k`.

**Result: no reproducible successful unlock on this exact build was found in
the sources inspected.** This is a bounded search result, not a claim that no
working method exists.

## First-hand and closely related reports

| Evidence | Device/build | What it establishes |
|---|---|---|
| [sundave72, post 1165](https://xdaforums.com/t/free-xiaomi-17-series-redmi-k90-pro-max-bootloader-unlock-no-disassembly.4781471/post-90723695), September 3 | Exact `3.0.301.0.WPMEUXM.C07` | Asked which tool to use; not a success report. |
| [Reply 1169](https://xdaforums.com/t/free-xiaomi-17-series-redmi-k90-pro-max-bootloader-unlock-no-disassembly.4781471/post-90724933), September 4 | Reply to the exact-build question | Recommends July 22 tool, without a matching-device execution log. |
| [xfighter11, post 1173](https://xdaforums.com/t/free-xiaomi-17-series-redmi-k90-pro-max-bootloader-unlock-no-disassembly.4781471/post-90728267), September 6 | Poco F8 Ultra; exact firmware missing | Reports same slide-stage failure as another Global Poco owner. |
| [Shira129, post 1174](https://xdaforums.com/t/free-xiaomi-17-series-redmi-k90-pro-max-bootloader-unlock-no-disassembly.4781471/post-90728401), September 6 | Global Poco F8 Ultra; exact firmware missing | Says free method failed and a paid provider later unlocked it. No reproducible procedure or payload identity. |
| [wileecoyote7, posts 38–40](https://xdaforums.com/t/pocof8ultra-redmi-k90-pro-max-unlock-bootloader-tutorial.4781632/page-2), August 28 | `3.0.2.0.WPMMIXM`, November 1, 2025 patch | First-hand success after discussion of the older tool. Different firmware; exact downloaded artifact hash absent. |
| [Posts 1156 and 1159](https://xdaforums.com/t/free-xiaomi-17-series-redmi-k90-pro-max-bootloader-unlock-no-disassembly.4781471/page-58) | Global Poco bootloop report; separately Poco `3.0.302.0` error | Counterevidence to blanket compatibility claims. A reply attributes the bootloop to script path handling, but we have not independently established that cause. |

The July tool also has first-hand success reports for Xiaomi 17 variants. Those
are evidence for those devices, not a substitute for myron EEA evidence.

## Newer method versus the ZIP already inspected

The [XDA main post](https://xdaforums.com/t/free-xiaomi-17-series-redmi-k90-pro-max-bootloader-unlock-no-disassembly.4781471/)
has a July 22 update claiming support for later Android 16 patches and points to
a newer package. Its technical discussion includes temporary root via
`CVE-2026-43499` and replacement ABL/EFI components. It is different from the
March OEM-command package supplied earlier. The announcement mixes older and
newer advice; version thresholds for Xiaomi 17 must not be transplanted to Poco
regional builds. Its claims about permanent hardware fuses also change between
dated updates; they are not accepted here as independently verified facts.

A forum reply links [Linuxoid-cn/Mi8E5-Unlocker-by-CVE-2026-43499](https://github.com/Linuxoid-cn/Mi8E5-Unlocker-by-CVE-2026-43499).
The repository describes a Windows package containing preload, EFI, wipe and
device-specific ABL files, including myron. It labels itself Testing, provides
no exact EEA compatibility matrix in its README, and is archived. The public
issues API returned zero items. This is an attributable lead, not a validated
solution for our build. We have not established byte identity between its
releases and the July Google Drive package.

## Taiwan port evidence

The [port author's August 4 write-up](https://b-log.to/tech-analysis/myron-taiwan-kernel-ghostlock-offsets/)
describes earlier failed attempts, deriving static offsets and compiling the
target. It does not provide an end-to-end successful unlock log for that target.
The [v0.1.0 release](https://github.com/jason5545/ghostlock-myron-tw/releases/tag/v0.1.0)
identifies the matching kernel but does not add such a log. Public issues API:
zero items. Our successful offline checks remain useful but cannot fill that gap.

## Search coverage and limits

- Web searches combined myron, WPMEUXM, 3.0.301, GhostLock, unlock and April.
- Read XDA's current myron forum listing, recent free-tool question thread,
  Stuart Cui tutorial page 2, and main July-method post plus pages 58–60.
  Read through the browser because web fetch returned 403. Did not inspect all
  60 discussion pages or private Telegram/paid-provider conversations.
- Queried all 47 returned upstream GhostLock issues/PR entries for myron/K90/F8
  title/body matches; none matched. This did not search every issue comment.
- Saved GitHub response snapshots under ignored
  `research/private/success-report-search/`.
- Commercial model lists and firmware-download listings were not accepted as
  execution evidence. No provider was contacted, paid, or recommended.

## Evidence needed to proceed with a proven method

A report should identify the original locked build, kernel, tool revision/hash,
actual successful root stage, unlocked state and successful boot afterward.
Updating an already-unlocked phone to our build is not evidence that unlocking
from our locked build works. A rooted-shell screenshot alone is not an unlock.

The most focused next inquiry is the exact-build XDA discussion above. Suggested
question, **draft only; not posted**:

> Has anyone successfully unlocked a POCO F8 Ultra EEA starting from locked
> OS3.0.301.0.WPMEUXM.C07, patch 2026-04-01, kernel
> 6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k? Please identify the exact tool
> version/hash and provide redacted root/unlock logs plus confirmation that the
> device booted afterward. Was this build installed before the unlock?

Until that evidence is available, the July tool remains an experiment, not a
proven procedure for this phone. The official Xiaomi authorization route remains
a separate avenue; our account eligibility has not been established here.
