#!/system/bin/sh
set -eu

EXPECTED_MODEL=25102PCBEG
EXPECTED_DEVICE=myron
EXPECTED_BUILD=OS3.0.301.0.WPMEUXM
EXPECTED_KERNEL=6.12.23-android16-5-g5a0e85dd9db0-ab14499855-4k
EXPECTED_PROBE_SHA256=08ad10ab574fe183f5d7f764ad11879b436191ce5e8d3710e6de415dd12c00eb
EXPECTED_EMPTY_EFISP_SHA256=bbd05cf6097ac9b1f89ea29d2542c1b7b67ee46848393895f5a9e43fa1f621e5
EXPECTED_STAGED_EFISP_SHA256=1e196189e9683a2c49365902949152eb583254000db06e9f93aff4f135ab2171
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
[ "$(getprop ro.boot.slot_suffix)" = _b ] || fail "expected active slot _b"

[ "$#" = 2 ] || fail "usage: $0 BACKUP_DIR PROBE_EFI"
BACKUP_DIR=${1%/}
PROBE=$2
EFISP=/dev/block/by-name/efisp

[ -f "$BACKUP_DIR/STATUS" ] || fail "missing original backup status"
grep -q '^COMPLETE$' "$BACKUP_DIR/STATUS" || fail "original backup is incomplete"
[ -f "$BACKUP_DIR/gpt-edges/STATUS" ] || fail "missing GPT backup status"
grep -q '^COMPLETE$' "$BACKUP_DIR/gpt-edges/STATUS" || fail "GPT backup is incomplete"
[ -f "$BACKUP_DIR/efisp.img" ] || fail "missing efisp backup"
[ -f "$PROBE" ] || fail "missing probe EFI"
[ -b "$EFISP" ] || fail "missing live efisp block device"

[ "$(hash_file "$PROBE")" = "$EXPECTED_PROBE_SHA256" ] || fail "probe hash mismatch"
[ "$(blockdev --getsize64 "$EFISP")" = "$EXPECTED_EFISP_SIZE" ] || fail "efisp size mismatch"
[ "$(hash_file "$BACKUP_DIR/efisp.img")" = "$EXPECTED_EMPTY_EFISP_SHA256" ] || fail "backup efisp hash mismatch"
[ "$(hash_file "$EFISP")" = "$EXPECTED_EMPTY_EFISP_SHA256" ] || fail "live efisp is not the backed-up empty image"

echo "All exact-target and backup guards passed."
echo "Writing the 40 KiB READ-ONLY probe to the 3 MiB efisp partition..."
dd if="$PROBE" of="$EFISP" bs=4096 count=10 conv=fsync status=none
sync

staged_hash=$(hash_file "$EFISP")
if [ "$staged_hash" != "$EXPECTED_STAGED_EFISP_SHA256" ]; then
    echo "ERROR: staged efisp hash mismatch; restoring verified empty backup" >&2
    dd if="$BACKUP_DIR/efisp.img" of="$EFISP" bs=4096 conv=fsync status=none
    sync
    [ "$(hash_file "$EFISP")" = "$EXPECTED_EMPTY_EFISP_SHA256" ] || \
        fail "automatic efisp restoration also failed"
    fail "probe staging failed; original efisp was restored"
fi

echo "READ-ONLY EFI probe staged and full-partition hash verified."
echo "efisp SHA256: $staged_hash"
echo "No slot metadata was changed and no reboot was requested."
