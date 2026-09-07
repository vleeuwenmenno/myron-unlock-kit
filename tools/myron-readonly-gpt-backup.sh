#!/system/bin/sh
set -eu

EXPECTED_MODEL=25102PCBEG
EDGE_SECTORS=2048

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ "$(id -u)" = 0 ] || fail "run this from the temporary root shell"
[ "$(getprop ro.product.model)" = "$EXPECTED_MODEL" ] || fail "wrong model"
[ "$(getprop ro.product.device)" = myron ] || fail "wrong device codename"

[ "$#" = 1 ] || fail "usage: $0 /data/local/tmp/myron-bootchain-backup-TIMESTAMP"
BACKUP_DIR=${1%/}
[ -d "$BACKUP_DIR" ] || fail "backup directory does not exist: $BACKUP_DIR"
[ -f "$BACKUP_DIR/STATUS" ] || fail "missing original backup STATUS file"
grep -q '^COMPLETE$' "$BACKUP_DIR/STATUS" || fail "original backup is not complete"

OUT="$BACKUP_DIR/gpt-edges"
[ ! -e "$OUT" ] || fail "refusing to overwrite existing GPT backup: $OUT"
mkdir -m 0700 "$OUT"

: > "$OUT/GPT_SHA256SUMS"
: > "$OUT/LUN_SIZES.txt"

for name in sda sdb sdc sdd sde sdf; do
    dev="/dev/block/$name"
    [ -b "$dev" ] || fail "missing block device: $dev"
    sectors=$(cat "/sys/class/block/$name/size")
    [ "$sectors" -gt "$EDGE_SECTORS" ] || fail "$name is unexpectedly small"
    tail_skip=$((sectors - EDGE_SECTORS))

    echo "$name sectors_512=$sectors bytes=$((sectors * 512))" >> "$OUT/LUN_SIZES.txt"
    dd if="$dev" of="$OUT/$name-first-1MiB.bin" bs=512 count="$EDGE_SECTORS" 2>/dev/null
    dd if="$dev" of="$OUT/$name-last-1MiB.bin" bs=512 skip="$tail_skip" count="$EDGE_SECTORS" 2>/dev/null
done

(
    cd "$OUT"
    sha256sum LUN_SIZES.txt *.bin > GPT_SHA256SUMS
    sha256sum -c GPT_SHA256SUMS
)
echo COMPLETE > "$OUT/STATUS"
chmod 0755 "$OUT"
chmod 0644 "$OUT"/*
sync

echo "Read-only GPT/LUN-edge backup complete: $OUT"
