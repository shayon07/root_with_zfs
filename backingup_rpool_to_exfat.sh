# ==============================================================================
# Backup and Restore a ZFS rpool using an exFAT Drive
# ==============================================================================

# Boot into a Linux live ISO with ZFS and exFAT support before starting.

# ==============================================================================
# BACKUP RPOOL TO AN EXFAT DRIVE
# ==============================================================================

# Import the pool if it is not already imported.
# sudo zpool import -N rpool
# sudo zpool import rpool

# Create a recursive snapshot of the entire pool.
sudo zfs snapshot -r rpool@migration

# Create a temporary mount point.
mkdir -p /mst/exfat_drive

# Mount the exFAT drive (replace /dev/sda3 if necessary).
sudo mount -t exfat /dev/sda3 /mst/exfat_drive

# Create the backup stream.
sudo zfs send -R rpool@migration | sudo tee /mst/exfat_drive/rpool-backup.zfs > /dev/null

# Verify the backup file exists.
ls -lh /mst/exfat_drive/rpool-backup.zfs

# Optional: Verify the stream is readable.
# zstreamdump /mst/exfat_drive/rpool-backup.zfs | head

# Unmount the backup drive.
sudo umount /mst/exfat_drive

# Remove the temporary mount point.
rmdir /mst/exfat_drive

# ==============================================================================
# DESTROY / REPARTITION DISK (IF NEEDED)
# ==============================================================================
# Perform any partitioning or formatting here before creating the new pool.

# ==============================================================================
# CREATE A NEW POOL
# ==============================================================================

sudo zpool create -f \
  -o ashift=12 \
  -o autotrim=off \
  -O mountpoint=none \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O dnodesize=auto \
  rpool /dev/nvme0n1p2

# ==============================================================================
# RESTORE RPOOL FROM THE EXFAT DRIVE
# ==============================================================================

# Create a temporary mount point.
mkdir -p /mst/exfat_drive

# Mount the backup drive.
sudo mount -t exfat /dev/sda3 /mst/exfat_drive

# Restore the pool.
sudo zfs receive -F rpool < /mst/exfat_drive/rpool-backup.zfs

# Set the boot dataset (replace if your boot dataset is different).
sudo zpool set bootfs=rpool/ROOT/cachy rpool

# Verify the datasets were restored.
zfs list

# Verify the bootfs property.
zpool get bootfs rpool

# Unmount the backup drive.
sudo umount /mst/exfat_drive

# Remove the temporary mount point.
rmdir /mst/exfat_drive

# ==============================================================================
# FINAL STEPS
# ==============================================================================
# - Mount the restored root dataset.
# - Mount the EFI System Partition.
# - Chroot into the restored system.
# - Reinstall or regenerate your bootloader.
# - Export the pool if desired:
#     sudo zpool export rpool
# - Reboot.