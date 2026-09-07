#!/system/bin/sh
set -eu

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ "$(id -u)" = 0 ] || fail "must run from the temporary root shell"
[ "$(getprop ro.product.device)" = myron ] || fail "wrong device codename"
[ "$(getprop ro.product.model)" = 25102PCBEG ] || fail "wrong model"
[ "$(getprop ro.build.version.incremental)" = OS3.0.301.0.WPMEUXM ] ||
  fail "wrong firmware build"
[ "$(getprop ro.boot.flash.locked)" = 1 ] || fail "unexpected lock state"

parts="
abl_a abl_b
xbl_a xbl_b xbl_config_a xbl_config_b
uefi_a uefi_b uefisecapp_a uefisecapp_b uefivarstore
aop_a aop_b aop_config_a aop_config_b
cpucp_a cpucp_b devcfg_a devcfg_b hyp_a hyp_b
keymaster_a keymaster_b qupfw_a qupfw_b shrm_a shrm_b tz_a tz_b
storsec toolsfv qweslicstore_a qweslicstore_b
boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b
dtbo_a dtbo_b recovery_a recovery_b
vbmeta_a vbmeta_b vbmeta_system_a vbmeta_system_b
efisp frp misc devinfo secdata keystore fsg modemst1 modemst2 persist
"

for part in $parts; do
  [ -b "/dev/block/by-name/$part" ] || fail "missing partition: $part"
done

stamp=$(date +%Y%m%d-%H%M%S)
out="/data/local/tmp/myron-bootchain-backup-$stamp"
[ ! -e "$out" ] || fail "output already exists: $out"
umask 077
mkdir "$out"
echo INCOMPLETE > "$out/STATUS"

getprop > "$out/getprop.txt"
ls -la /dev/block/by-name > "$out/block-by-name.txt"
printf 'partition device bytes sha256\n' > "$out/MANIFEST.txt"
: > "$out/SHA256SUMS"

total=0
for part in $parts; do
  bytes=$(blockdev --getsize64 "/dev/block/by-name/$part") ||
    fail "cannot determine size: $part"
  total=$((total + bytes))
done
available_kb=$(df -k /data | awk 'NR == 2 {print $4}')
required_kb=$(((total + 1048575) / 1024 + 262144))
[ "$available_kb" -ge "$required_kb" ] ||
  fail "insufficient /data space: need ${required_kb} KiB, have ${available_kb} KiB"
echo "Backing up $total bytes into $out"

for part in $parts; do
  src="/dev/block/by-name/$part"
  dst="$out/$part.img"
  device=$(readlink -f "$src")
  expected=$(blockdev --getsize64 "$src")
  echo "READ $part ($expected bytes from $device)"
  if ! dd if="$src" of="$dst" bs=1048576 2>"$out/$part.dd.log"; then
    cat "$out/$part.dd.log" >&2
    fail "read failed: $part"
  fi
  actual=$(stat -c %s "$dst")
  [ "$actual" = "$expected" ] ||
    fail "size mismatch for $part: expected $expected, copied $actual"
  digest=$(sha256sum "$dst" | awk '{print $1}')
  printf '%s  %s.img\n' "$digest" "$part" >> "$out/SHA256SUMS"
  printf '%s %s %s %s\n' "$part" "$device" "$actual" "$digest" \
    >> "$out/MANIFEST.txt"
done

(cd "$out" && sha256sum -c SHA256SUMS) >&2
echo COMPLETE > "$out/STATUS"
sync
chown -R shell:shell "$out"
chmod -R u+rwX,go-rwx "$out"
echo "BACKUP_DIR=$out"
echo "Read-only boot-chain backup complete. Keep the root shell open."
