#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "usage: $0" >&2
    exit 2
fi

tools_dir=$(cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$tools_dir/bin"

cc -std=c11 -O2 -Wall -Wextra -Werror \
  "$tools_dir/source/myron_fastboot_raw.c" \
  $(pkg-config --cflags --libs libusb-1.0) \
  -o "$tools_dir/bin/myron-fastboot-raw"

sha256sum "$tools_dir/bin/myron-fastboot-raw"
