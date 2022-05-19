#!/bin/bash

# Multistrap hook file to create fstab inside new root.

dir=${1%%/}
mode=$2

# Run only at start
[ "$mode" = "start" ] || exit 0

check_path() {
    local path=${dir}/$1
    if [ ! -d $path ] ; then
	echo "$path missing, can't set up" >&2
	exit -1
    fi
}

# Get swap partition on same device as specified partition
find_swap() {
    rp=$(basename $1)
    dev=$(ls -d /sys/block/*/$rp 2>/dev/null) || return
    dev=$(basename $(dirname $dev) 2>/dev/null) || return

    swp=$(blkid -t TYPE="swap" | grep "/dev/$dev" | cut -f1 -d: | head -1)
    if [ -n "$swp" ] ; then
	eval $(blkid $swp -o export)
	SWAP_UUID=${UUID}
	DISABLE_SWAP=""
    fi
}

# Check if there is an EFI-SYSTEM partition to mount at /boot/efi
# Will mount this one by label so you must create it with EFI-SYSTEM as
# the label, and to keep grub happy EFI-System as the partlabel.
find_efi() {
    mountpoint -q ${dir}/boot/efi || return
    rp=$(basename $1)
    dev=$(ls -d /sys/block/*/$rp 2>/dev/null) || return
    dev=$(basename $(dirname $dev) 2>/dev/null) || return

    efi=$(blkid -t LABEL="EFI-SYSTEM" | grep "/dev/$dev" | cut -f1 -d: | head -1)
    if [ -n "$efi" ] ; then
	DISABLE_EFI=""
    fi
    
}

find_root() {
    root=$(mount | grep ${dir} | cut -f1 | head -1)
    if [ -n "$root" ] ; then
	eval $(blkid $root -o export)
	if [ -n "${UUID}" ] ; then
	    ROOT_UUID=${UUID}
	    ROOT_DEV=${DEVNAME}
	    DISABLE_ROOT=""
	fi
    fi
}

check_path ""

mkdir --parents ${dir}/mnt/data

DISABLE_SWAP="# "
DISABLE_ROOT="# "
DISABLE_EFI="# "
ROOT_DEV=""

find_root
if [ -z "$ROOT_DEV" ] ; then
    echo "Install root is not a mounted device, setup manually."
    # Not fatal just create with all disabled.
else
    find_swap $ROOT_DEV
    find_efi  $ROOT_DEV
fi

cat <<EOF > ${dir}/etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>

# root partition.  You may have to use blkid to find UUID
${DISABLE_ROOT}UUID=${ROOT_UUID} /               ext4    errors=remount-ro 0       1

# swap partition.  You may have to use blkid to find UUID.
${DISABLE_SWAP}UUID=${SWAP_UUID} none            swap    sw              0       0

# Mount efi partition if we have one
${DISABLE_EFI}LABEL=EFI-SYSTEM   /boot/efi       vfat   rw     0 0
 

# Update label if this is not the name of your BTRFS partition.
LABEL=USB_BTRFS_DATA /mnt/data btrfs nofail,x-gvfs-show,noauto 0 0

EOF

