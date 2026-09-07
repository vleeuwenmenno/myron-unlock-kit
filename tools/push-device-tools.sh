#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 ADB_SERIAL" >&2
    exit 2
fi

serial=$1
kit_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)

model=$(adb -s "$serial" shell getprop ro.product.model | tr -d '\r')
device=$(adb -s "$serial" shell getprop ro.product.device | tr -d '\r')
build=$(adb -s "$serial" shell getprop ro.build.version.incremental | tr -d '\r')
kernel=$(adb -s "$serial" shell uname -r | tr -d '\r')

[[ "$model" == 25102PCBEG ]] || { echo "wrong model: $model" >&2; exit 1; }
[[ "$device" == myron ]] || { echo "wrong device: $device" >&2; exit 1; }
[[ "$build" == OS3.0.301.0.WPMEUXM ]] || { echo "wrong build: $build" >&2; exit 1; }
[[ "$kernel" == 6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k ]] || {
    echo "wrong kernel: $kernel" >&2
    exit 1
}

adb -s "$serial" push "$kit_dir/tools/myron-readonly-bootchain-backup.sh" /data/local/tmp/
adb -s "$serial" push "$kit_dir/tools/myron-readonly-gpt-backup.sh" /data/local/tmp/
adb -s "$serial" push "$kit_dir/tools/myron-stage-readonly-efi-probe.sh" /data/local/tmp/
adb -s "$serial" push "$kit_dir/tools/myron-stage-unlock-efi.sh" /data/local/tmp/
adb -s "$serial" push "$kit_dir/tools/bin/myron-bootctl" /data/local/tmp/
adb -s "$serial" push "$kit_dir/payloads/myron-gbl-readonly-probe.efi" /data/local/tmp/
adb -s "$serial" push "$kit_dir/payloads/Unlocking-SM8850.efi" /data/local/tmp/myron-unlock.efi
adb -s "$serial" shell chmod 755 /data/local/tmp/myron-bootctl

echo "Exact target verified and device-side tools pushed."
