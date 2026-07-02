#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${1:-}"
TARGET_UID=1000

if [[ -z "$TARGET_USER" ]]; then
  echo "Error: missing target user."
  exit 1
fi

echo "==> Setting hostid"
if command -v zgenhostid &>/dev/null; then
  zgenhostid
else
  hostid > /etc/hostid
fi

echo "==> Finding EFI partition"
EFI_PART="$(lsblk -rpo NAME,TYPE,FSTYPE | awk '$2=="part" && $3=="vfat"{print $1; exit}')"
if [[ -z "$EFI_PART" ]]; then
  echo "Error: EFI partition not found."
  exit 1
fi

mkdir -p /boot/efi
mount "$EFI_PART" /boot/efi

if id "$TARGET_USER" &>/dev/null; then
  usermod -u "$TARGET_UID" "$TARGET_USER" || true
else
  useradd -u "$TARGET_UID" -m -G wheel -s /bin/bash "$TARGET_USER"
fi

if id "$TARGET_USER" &>/dev/null; then
  chown -R "$TARGET_USER:$TARGET_USER" "/home/${TARGET_USER}" || true
fi

if [[ -f /etc/mkinitcpio.conf ]]; then
  sed -i 's/^MODULES=(/MODULES=(zfs /' /etc/mkinitcpio.conf || true
  sed -i 's/^HOOKS=(.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block zfs filesystems fsck)/' /etc/mkinitcpio.conf || true
fi

if command -v mkinitcpio &>/dev/null; then
  mkinitcpio -P
fi

if command -v systemctl &>/dev/null; then
  systemctl enable zfs-import-cache.service zfs-mount.service zfs-zed.service zfs.target zfs-import.target || true
fi

mkdir -p /etc/zfs/zfs-list.cache
touch /etc/zfs/zfs-list.cache/rpool

umount /boot/efi
echo "Chroot setup complete."
