#!/system/bin/sh
set -eu

EXPECTED_MODEL=25102PCBEG
EXPECTED_DEVICE=myron
EXPECTED_BUILD=OS3.0.301.0.WPMEUXM
EXPECTED_KERNEL=6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k
EXPECTED_PAYLOAD_SHA256=88918dd212fefe9d51c584513cbb7babebf395879d9edc2a02acd4246b5bcf5d
EXPECTED_PROBE_SHA256=08ad10ab574fe183f5d7f764ad11879b436191ce5e8d3710e6de415dd12c00eb
EXPECTED_EMPTY_EFISP_SHA256=bbd05cf6097ac9b1f89ea29d2542c1b7b67ee46848393895f5a9e43fa1f621e5
EXPECTED_PROBE_EFISP_SHA256=1e196189e9683a2c49365902949152eb583254000db06e9f93aff4f135ab2171
EXPECTED_UNLOCK_EFISP_SHA256=823bfe06165e570c9d6abdf518a09edb032676e9cbc8cf708d85aa3cbedeb3f4
EXPECTED_EFISP_SIZE=3145728

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

hash_file() {
    sha256sum "$1" | awk '{print $1}'
}

[ "$(id -u)" = 0 ] || fail "run this from the temporary root shell"
[ "$(getprop ro.product.model)" = "$EXPECTED_MODEL" ] || fail "wrong model"
[ "$(getprop ro.product.device)" = "$EXPECTED_DEVICE" ] || fail "wrong device"
[ "$(getprop ro.build.version.incremental)" = "$EXPECTED_BUILD" ] || fail "wrong build"
[ "$(uname -r)" = "$EXPECTED_KERNEL" ] || fail "wrong kernel"
[ "$(getprop ro.boot.slot_suffix)" = _b ] || fail "expected running slot _b"

[ "$#" = 3 ] || fail "usage: $0 BACKUP_DIR READONLY_PROBE UNLOCK_EFI"
BACKUP_DIR=${1%/}
PROBE=$2
PAYLOAD=$3
EFISP=/dev/block/by-name/efisp

[ -f "$BACKUP_DIR/STATUS" ] || fail "missing original backup status"
grep -q '^COMPLETE$' "$BACKUP_DIR/STATUS" || fail "original backup is incomplete"
[ -f "$BACKUP_DIR/gpt-edges/STATUS" ] || fail "missing GPT backup status"
grep -q '^COMPLETE$' "$BACKUP_DIR/gpt-edges/STATUS" || fail "GPT backup is incomplete"
[ -f "$BACKUP_DIR/efisp.img" ] || fail "missing efisp backup"
[ -f "$PROBE" ] || fail "missing read-only probe"
[ -f "$PAYLOAD" ] || fail "missing unlock EFI"
[ -b "$EFISP" ] || fail "missing live efisp block device"

[ "$(hash_file "$PROBE")" = "$EXPECTED_PROBE_SHA256" ] || fail "probe hash mismatch"
[ "$(hash_file "$PAYLOAD")" = "$EXPECTED_PAYLOAD_SHA256" ] || fail "unlock EFI hash mismatch"
[ "$(blockdev --getsize64 "$EFISP")" = "$EXPECTED_EFISP_SIZE" ] || fail "efisp size mismatch"
[ "$(hash_file "$BACKUP_DIR/efisp.img")" = "$EXPECTED_EMPTY_EFISP_SHA256" ] || fail "backup efisp hash mismatch"
live_hash=$(hash_file "$EFISP")
if [ "$live_hash" = "$EXPECTED_PROBE_EFISP_SHA256" ]; then
    ROLLBACK_SOURCE=$PROBE
    ROLLBACK_COUNT='count=10'
    ROLLBACK_SHA256=$EXPECTED_PROBE_EFISP_SHA256
    echo "Verified live efisp contains the read-only probe."
elif [ "$live_hash" = "$EXPECTED_EMPTY_EFISP_SHA256" ]; then
    ROLLBACK_SOURCE=$BACKUP_DIR/efisp.img
    ROLLBACK_COUNT=''
    ROLLBACK_SHA256=$EXPECTED_EMPTY_EFISP_SHA256
    echo "Verified live efisp matches the original empty backup."
else
    fail "live efisp matches neither the empty backup nor the verified probe"
fi

echo "All exact-target, backup, probe, and payload guards passed."
echo "Writing the reviewed 40 KiB unlock EFI..."
dd if="$PAYLOAD" of="$EFISP" bs=4096 count=10 conv=fsync status=none
sync

staged_hash=$(hash_file "$EFISP")
if [ "$staged_hash" != "$EXPECTED_UNLOCK_EFISP_SHA256" ]; then
    echo "ERROR: unlock EFI readback mismatch; restoring prior efisp state" >&2
    if [ -n "$ROLLBACK_COUNT" ]; then
        dd if="$ROLLBACK_SOURCE" of="$EFISP" bs=4096 count=10 conv=fsync status=none
    else
        dd if="$ROLLBACK_SOURCE" of="$EFISP" bs=4096 conv=fsync status=none
    fi
    sync
    [ "$(hash_file "$EFISP")" = "$ROLLBACK_SHA256" ] || \
        fail "automatic efisp restoration also failed"
    fail "unlock EFI staging failed; prior efisp state was restored"
fi

echo "Unlock EFI staged and full-partition hash verified."
echo "efisp SHA256: $staged_hash"
echo "No ABL partition was written and no reboot was requested."
