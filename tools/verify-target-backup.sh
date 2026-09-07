#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 BACKUP_DIR" >&2
    exit 2
fi

backup_dir=${1%/}
[[ -f "$backup_dir/STATUS" ]] || { echo "missing STATUS" >&2; exit 1; }
[[ $(<"$backup_dir/STATUS") == COMPLETE ]] || { echo "backup incomplete" >&2; exit 1; }
[[ -f "$backup_dir/gpt-edges/STATUS" ]] || { echo "missing GPT STATUS" >&2; exit 1; }
[[ $(<"$backup_dir/gpt-edges/STATUS") == COMPLETE ]] || { echo "GPT backup incomplete" >&2; exit 1; }

check_hash() {
    local expected=$1 file=$2 actual
    actual=$(sha256sum "$file" | awk '{print $1}')
    [[ "$actual" == "$expected" ]] || {
        echo "hash mismatch: $file" >&2
        echo "expected $expected" >&2
        echo "actual   $actual" >&2
        exit 1
    }
}

check_hash dce32572f3740ed058cd033f40b2009ef6b241170a913aba0b2714178498d8db "$backup_dir/abl_a.img"
check_hash 1a2f9c76516d697d55e37954c975aef228fbc937527b2b9887289f24c7d7e24e "$backup_dir/abl_b.img"
check_hash bbd05cf6097ac9b1f89ea29d2542c1b7b67ee46848393895f5a9e43fa1f621e5 "$backup_dir/efisp.img"

echo "Required native ABL A, stock ABL B, empty efisp, and GPT backup verified."

