# First boot into a live Linux environment that supports ZFS and exFAT.

#===============================Backup rpool to exFAT drive===============================
# Take a snapshot of the pool
sudo zfs snapshot -r rpool@migration

# Create a temporary directory to mount the exFAT drive
mkdir -p /mst/exfat_drive

# Mount the exFAT drive (replace /dev/sdX1 with your actual device)
sudo mount -t exfat /dev/sda3 /mst/exfat_drive

# Use zfs send to send the snapshot to the exFAT drive
sudo zfs send -R rpool@migration | sudo tee /mst/exfat_drive/rpool-backup.zfs > /dev/null

# Unmount the exFAT drive
sudo umount /mst/exfat_drive
# Remove the temporary directory
rmdir /mst/exfat_drive
#==========================================================================================

#==============================Restore rpool from exFAT drive==============================
# Create a temporary directory to mount the exFAT drive
mkdir -p /mst/exfat_drive

# Mount the exFAT drive (replace /dev/sdX1 with your actual device)
sudo mount -t exfat /dev/sda3 /mst/exfat_drive

# Use zfs receive to restore the snapshot from the exFAT drive
sudo zfs receive -Fdu rpool < /mst/exfat_drive/rpool-backup.zfs

# Unmount the exFAT drive
sudo umount /mst/exfat_drive

# Remove the temporary directory
rmdir /mst/exfat_drive

#=========================================================================================
