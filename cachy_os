# This script is supplement to the pop_os scripts
#  for remaining steps here i.e., setting up ZBM, creating zfs pools refer to
#   scripts under pop_os directory
#
# covered:
#  https://codeishot.com/1BIXGoSK
# 1. https://codeishot.com/5vDs3olZ
# 2. https://codeishot.com/2HD7Zl4j
# 3. https://codeishot.com/6C5wpRLA
#
# prior ones:
# - https://codeishot.com/TH4JkrA3
# - https://codeishot.com/74SaocDB
#
# Perp: https://www.perplexity.ai/search/instruction-to-install-cachyos-fs6xe_4VQ9mGEhmNDBoAag
#
# more perp: CachyOS instruction for installation:
#  https://www.perplexity.ai/search/cachy-linux-root-with-zfs-stri-pMOqHiZ7TJuL3j8.z9eVfQ#3
#
# Source live media: /dev/sda
# A temporary external flash disk is used to get copy of the installation media
#  which is /dev/sdb (as its plugged in after the live media is booted)
#

# mount source
sudo mkdir /mst
# specify FS type is required for CachyOS live
#  temp flash disk:
#  part#1 /boot + ESP (unlike pop, /boot resides on part#1 alongside ESP)
#  part#2 ext4 partition
# cachyos installer zfs install on external SSD still fails, hence, we default to ext4
sudo mount --types ext4 --source /dev/sdb2 --target /mst
sudo ls -alsh /mst

# import root pool (usually in a parition of /dev/nvme0n1 )
sudo zpool import -N rpool -R /mnt

# mount zfs datasets for cachy; zfs mount -a isn't enough
sudo zfs mount rpool/ROOT/cachy
sudo zfs mount rpool/var/log
sudo zfs mount rpool/home

# Observe output to make sure there's no copy paste error in cachy datasets
#  (source we are copying from had datasets for pop_os)
zfs list -o name,mountpoint,canmount,mounted

# take care of users for other OSs in /home if next rsync will overwrite user's files: /home/$USER

# copy over the cachyos install, we have --delete here
sudo rsync --archive --hard-links --acls --xattrs --one-file-system --numeric-ids --sparse --info=progress2 --human-readable --delete --exclude={'/dev/','/proc/','/sys/','/tmp/','/run/','/media/','/lost+found'} /mst/ /mnt/

# user's home dir perms ownerships are preserved by rsync, so no need to change
# those
# Optionally, cleanup multiple user home dirs from /home if /home is shared
# among multiple OSs

# copy over /boot from cachyos install
sudo umount /mst
# probably specifying FS type isn't required, but this makes it readable
sudo mount --types vfat --source /dev/sdb1 --target /mst
sudo ls -alsh /mst
# copy op
sudo rsync --archive --hard-links --acls --xattrs --one-file-system --numeric-ids --sparse --info=progress2 --human-readable --delete /mst/ /mnt/boot/

# not required, yet we run
sudo zpool sync rpool

# move some of the extra dirs
pushd /mnt/boot
sudo mkdir bak
sudo mv EFI 016afea3445243be9e28ff89d446005c/ bak/
popd

sudo umount /mst
sudo rmdir /mst
# done with temp SSD
sudo eject /dev/sdb2
sudo eject /dev/sdb1
sudo eject /dev/sdb

# update /etc/fstab on the install
ls -l /dev/disk/by-partuuid/
# 1c637ef4-9d7f-4301-aad0-82eefccb4370
# example line from pop_os
# PARTUUID=1c637ef4-9d7f-4301-aad0-82eefccb4370  /boot/efi  vfat  umask=0077  0  0
sudo vim /mnt/etc/fstab

sudo mkdir -p /mnt/dev /mnt/dev/pts /mnt/proc /mnt/sys /mnt/run /mnt/tmp

sudo mount --bind /dev /mnt/dev
sudo mount --bind /dev/pts /mnt/dev/pts
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo mount --bind /run /mnt/run
sudo mount --bind /tmp /mnt/tmp

############# chroot env #############
# look up on arch-chroot
sudo arch-chroot /mnt /bin/bash

hostid > /etc/hostid

mkdir /boot/efi/
mount /dev/nvme0n1p1 /boot/efi/
ls -a /boot/efi/

# initramfs modules alternative
sudo vim /etc/mkinitcpio.conf
# appy changes below
MODULES=(zfs)
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block zfs filesystems fsck)
# also remove any 'resume= UID* entries from /etc/mkinitcpio.conf to disable resume on initramfs

depmod --all 6.17.1-2-cachyos

# install zfs modules prebuilt packages
pacman --sync --refresh --sysupgrade --needed linux-cachyos zfs-utils linux-cachyos-zfs

# verify
grep zfs /usr/lib/modules/6.17.1-2-cachyos/modules.dep
# output:
# zfs.ko.zst: spl.ko.zst

# remove lts kernel that doesn't have zfs modules
# pacman figoure out args to remove linux-cachyos
# TODO: check battery / power consumption impact of zfs-zed.service

# zfs-zed for health monitoring
systemctl enable zfs-import-cache.service zfs-mount.service zfs-zed.service

# to make the automount of non root datasets work
#  ref, https://www.perplexity.ai/search/i-have-root-with-zfs-setup-on-RwOY26oJRXy1kpfMGDwp9w#0
mkdir -p /etc/zfs/zfs-list.cache && touch /etc/zfs/zfs-list.cache/rpool
# probably just these services are enough but need to test
sudo systemctl enable zfs.target zfs-import.target

mkinitcpio --preset linux-cachyos
# manual target example if required
# mkinitcpio --config /etc/mkinitcpio.conf   --generate /boot/initramfs-linux-cachyos.img   --kernel 6.17.1-2-cachyos

# remove lts kernel: 'linux-cachyos-lts'
# figure out pacman cmd for that

sudo udevadm trigger

# prepare to exit
sudo umount /boot/efi/

# from chroot
exit

sudo umount /mnt/run
sudo umount /mnt/proc
sudo umount /mnt/dev/pts
sudo umount /mnt/dev
sudo umount /mnt/tmp
sudo umount -l /mnt/sys

sudo zfs umount rpool/home
sudo zfs umount rpool/var/log
sudo zfs umount rpool/ROOT/cachy

# configure ZFS Boot Menu options
# Look up kernel params from /mnt/boot/entries/*
#  options root=UUID=f950fbe0-72cc-49d1-87a3-7e631ff5e41c rw rootflags=subvol=/@ zswap.enabled=0 nowatchdog splash
# root prefix is different on arch based systems **
#  may be also add spl.spl_hostid after rw
# ZFSBootMenu KCL without root= i.e., zfs=rpool/ROOT/cachy
sudo zfs set org.zfsbootmenu:commandline="rw spl.spl_hostid=0x4ae85d7f loglevel=4 zswap.enabled=0 systemd.show_status=true systemd.log_level=debug" rpool/ROOT/cachy
# name
# sudo zfs set org.zfsbootmenu:name="CachyOS 6.17" rpool/ROOT/cachy
# desc
# sudo zfs set org.zfsbootmenu:description="CachyOS mainline kernel" rpool/ROOT/cachy

# sudo umount /mnt/boot/efi
sudo zpool export rpool

# Setup BootLoader
#  we did this part during last pop_os installation
# set bootfs on rpool
# ref: admin/create_gpt_parts.nu check efibootmgr cmd
