#!/bin/bash

# Multistrap hook file to install grub bootloader so native images
# can boot.

dir=${1%%/}
mode=$2

# we only process start so unmount can be at end
[ "$mode" = "end" ] || exit 0

check_path() {
    local path=$dir/$1
    if [ ! -d $path ] ; then
	echo "$path missing, can't set up" >&2
	exit -1
    fi
}

# Sanity check that grub can work.
check_path "proc"
check_path "sys"
check_path "dev"

# Find installed disk
root=$(mount | grep ${dir} | cut -f1 | head -1)
dev=$(lsblk -ndo pkname $root 2>/dev/null)

if [ -z "$dev" ] ; then
    echo "Could not find block device for $dir" >&2
    exit -1
fi

# Get rid of os_loader -- it sets up grub entries for stuff here on
# our host system which is useless and confusing.
prober="30_os-prober"
if [ -f ${dir}/etc/grub/${prober} ] ; then
    mkdir -p ${dir}/etc/grub/removed
    mv ${dir}/etc/grub/${prober} ${dir}/etc/grub/removed
fi
# Install legacy  bootloader
chroot $dir grub-install --removable /dev/${dev}
# Install EFI bootloader if efi FAT partition is mounted
if mountpoint -q ${dir}/boot/efi ; then
    chroot $dir grub-install --removable --target=x86_64-efi --efi-directory /boot/efi --bootloader-id=Ubuntu
fi
# Re-generate config
chroot $dir update-grub2
