#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY-RUN] '; printf '%q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

cleanup() {
  local rc=$?
  if mountpoint -q /mnt/run 2>/dev/null; then run umount -l /mnt/run || true; fi
  if mountpoint -q /mnt/proc 2>/dev/null; then run umount -l /mnt/proc || true; fi
  if mountpoint -q /mnt/dev/pts 2>/dev/null; then run umount -l /mnt/dev/pts || true; fi
  if mountpoint -q /mnt/dev 2>/dev/null; then run umount -l /mnt/dev || true; fi
  if mountpoint -q /mnt/tmp 2>/dev/null; then run umount -l /mnt/tmp || true; fi
  if mountpoint -q /mnt/sys 2>/dev/null; then run umount -l /mnt/sys || true; fi
  exit "$rc"
}
trap cleanup EXIT

echo "==> ZFS deployment setup"

read -rp "Source ext4 partition (example /dev/sdb2): " SOURCE_PART
read -rp "Target disk (example /dev/nvme0n1 or /dev/sdb): " TARGET_DISK
read -rp "OS identifier (example cachy): " OS_NAME
read -rp "Target username: " TARGET_USER

if [[ -z "$SOURCE_PART" || -z "$TARGET_DISK" || -z "$OS_NAME" || -z "$TARGET_USER" ]]; then
  echo "Missing required input."
  exit 1
fi

PART_ESP="${TARGET_DISK}1"
PART_ROOT="${TARGET_DISK}2"
ZBM_CMDLINE='rw spl.spl_hostid=0x4ae85d7f loglevel=4 zswap.enabled=0 systemd.show_status=true systemd.log_level=debug'

run mkdir -p /mnt
run mount --source "$SOURCE_PART" --target /mnt -o ro

if ! zpool list rpool &>/dev/null; then
  run zpool import -N rpool -R /mnt
fi

run zfs mount "rpool/ROOT/${OS_NAME}" || true

if ! zfs list "rpool/ROOT/${OS_NAME}/home" &>/dev/null; then
  run zfs create -p -o "mountpoint=/home/${TARGET_USER}" "rpool/ROOT/${OS_NAME}/home"
fi

if ! zfs list rpool/shared_data &>/dev/null; then
  run zfs create -p -o "mountpoint=/home/${TARGET_USER}/Shared" -o canmount=on rpool/shared_data
fi

run zfs mount "rpool/ROOT/${OS_NAME}/home" || true
run zfs mount rpool/shared_data || true
run zfs mount rpool/var/log || true

run mkdir -p /mnt/boot
run rsync -aHAX --numeric-ids --info=progress2 --delete \
  --exclude='/dev/' --exclude='/proc/' --exclude='/sys/' --exclude='/tmp/' \
  --exclude='/run/' --exclude='/media/' --exclude='/lost+found' \
  "$SOURCE_PART" /mnt/

echo "==> Mount ESP and copy boot files later inside chroot or after verifying layout."

run umount /mnt

run mkdir -p /mnt
run mount --source "$SOURCE_PART" --target /mnt -o ro

run mkdir -p /mnt/dev /mnt/dev/pts /mnt/proc /mnt/sys /mnt/run /mnt/tmp
run mount --bind /dev /mnt/dev
run mount --bind /dev/pts /mnt/dev/pts
run mount --bind /proc /mnt/proc
run mount --bind /sys /mnt/sys
run mount --bind /run /mnt/run
run mount --bind /tmp /mnt/tmp

run cp chroot-setup.sh /mnt/tmp/chroot-setup.sh
run chmod +x /mnt/tmp/chroot-setup.sh
run arch-chroot /mnt /bin/bash /tmp/chroot-setup.sh "$TARGET_USER"

run udevadm trigger || true
run umount -l /mnt/run || true
run umount -l /mnt/proc || true
run umount -l /mnt/dev/pts || true
run umount -l /mnt/dev || true
run umount -l /mnt/tmp || true
run umount -l /mnt/sys || true

run zfs umount rpool/shared_data || true
run zfs umount "rpool/ROOT/${OS_NAME}/home" || true
run zfs umount rpool/var/log || true
run zfs umount "rpool/ROOT/${OS_NAME}" || true

run zfs set org.zfsbootmenu:commandline="$ZBM_CMDLINE" "rpool/ROOT/${OS_NAME}"
run zpool export rpool

echo "Done."
