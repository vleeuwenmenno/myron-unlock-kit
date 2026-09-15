#!/system/bin/sh
set -eu

TWRP=/data/local/tmp/TWRP_myron_finix_20260809.img
STOCK=/data/local/tmp/recovery_b-stock-OS3.0.301.0.WPMEUXM.img
TARGET=/dev/block/by-name/recovery_b
TWRP_SHA=c963f75c3a51666db2a92d3b50f79f9fd4bf320cdef93ca45de9ab0ef27a6a53
STOCK_SHA=bfb8e0c2fa2e7c974e8ae5ca65cc80e0d60dd24076c61abae1445fff2788825d
SIZE=104857600

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ "$(id -u)" = 0 ] || fail "root UID required"
[ "$(getprop ro.product.device)" = myron ] || fail "wrong device"
[ "$(getprop ro.product.model)" = 25102PCBEG ] || fail "wrong model"
[ "$(getprop ro.build.version.incremental)" = OS3.0.301.0.WPMEUXM ] ||
  fail "wrong firmware"
[ "$(getprop ro.build.version.security_patch)" = 2026-04-01 ] ||
  fail "wrong security patch"
[ "$(getprop ro.boot.flash.locked)" = 0 ] || fail "bootloader is not unlocked"
[ "$(getprop ro.boot.slot_suffix)" = _b ] || fail "Android is not on slot B"
[ -b "$TARGET" ] || fail "recovery_b block device is missing"
[ -f "$TWRP" ] || fail "TWRP image is missing"
[ -f "$STOCK" ] || fail "stock recovery image is missing"

[ "$(wc -c < "$TWRP" | tr -d ' ')" = "$SIZE" ] || fail "wrong TWRP size"
[ "$(wc -c < "$STOCK" | tr -d ' ')" = "$SIZE" ] || fail "wrong stock size"
[ "$(sha256sum "$TWRP" | cut -d ' ' -f 1)" = "$TWRP_SHA" ] ||
  fail "TWRP hash mismatch"
[ "$(sha256sum "$STOCK" | cut -d ' ' -f 1)" = "$STOCK_SHA" ] ||
  fail "stock image hash mismatch"

echo "Reading current recovery_b before write..."
current_sha=$(sha256sum "$TARGET" | cut -d ' ' -f 1)
[ "$current_sha" = "$STOCK_SHA" ] ||
  fail "live recovery_b does not match the exact stock backup"

echo "Writing verified TWRP to recovery_b..."
dd if="$TWRP" of="$TARGET" bs=4194304
sync

echo "Reading recovery_b back for verification..."
readback_sha=$(sha256sum "$TARGET" | cut -d ' ' -f 1)
if [ "$readback_sha" != "$TWRP_SHA" ]; then
  echo "TWRP readback failed; restoring exact stock recovery_b..." >&2
  dd if="$STOCK" of="$TARGET" bs=4194304
  sync
  restored_sha=$(sha256sum "$TARGET" | cut -d ' ' -f 1)
  [ "$restored_sha" = "$STOCK_SHA" ] ||
    fail "automatic stock recovery restoration also failed"
  fail "TWRP write failed; stock recovery was restored"
fi

echo "TWRP recovery_b write and full-partition readback verified: $readback_sha"
echo "Exit the temporary-root shell so Android reboots and SELinux returns Enforcing."
