#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 ANDROID_NDK_ROOT ADB_SERIAL" >&2
    exit 2
fi

ndk_root=$1
serial=$2
tools_dir=$(cd -- "$(dirname -- "$0")" && pwd)
build_dir="$tools_dir/build-bootctl"
compiler="$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android35-clang++"
[[ -x "$compiler" ]] || { echo "missing compiler: $compiler" >&2; exit 1; }
mkdir -p "$build_dir" "$tools_dir/bin"

adb -s "$serial" pull /system/lib64/libboot_control_client.so "$build_dir/libboot_control_client.so"
adb -s "$serial" pull /system/lib64/libc++.so "$build_dir/libc++.so"

"$compiler" -std=c++17 -O2 -Wall -Wextra -Werror -fPIE -pie -nostdlib++ \
  "$tools_dir/source/myron_bootctl.cpp" \
  -L"$build_dir" -lboot_control_client -l:libc++.so \
  -o "$tools_dir/bin/myron-bootctl"

sha256sum "$tools_dir/bin/myron-bootctl"

