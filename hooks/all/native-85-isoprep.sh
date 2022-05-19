#!/bin/bash

rootfs=$(readlink -f $1)
if [ -z "${1}" ] || [ ! -d "${rootfs}" ] ; then
    echo "Can not find rootfs"
    exit 1
fi
mode=$2

# we only process start so unmount can be at end
[ "$mode" = "end" ] || exit 0

if [ ! -f ${rootfs}/etc/casper.conf ] ; then
    echo "INFO: Skipping Live setup -- casper not installed"
    # don't fail
    exit 0
fi

if [ ! $(id -u) -eq 0 ]; then
    if ! sudo -v 2>/dev/null; then
	echo "Sorry could not validate your credentials"
	echo
	echo "If this is an error edit the script to delete this check"
	echo "and you will be prompted below."
    fi
    prefix="sudo "
else
    prefix=""
fi


${prefix}mkdir -p ${rootfs}/boot/iso-image/isolinux
cat <<EOF | ${prefix}sed -n "w ${rootfs}/boot/iso-image/README"
This directory contains files used to create LiveCD images.
EOF

cat <<EOF | ${prefix}sed -n "w ${rootfs}/boot/iso-image/isolinux/grub.cfg"

search --set=root --file /ubuntu

insmod all_video

set default="0"
set timeout=30

menuentry "Boot Live Image" {
   linux /casper/vmlinuz boot=casper quiet splash ---
   initrd /casper/initrd
}

EOF

cat <<EOF | ${prefix}sed -n "w ${rootfs}/boot/iso-image/isolinux/isolinux.cfg"
UI vesamenu.c32
MENU TITLE Boot Menu
DEFAULT linux
TIMEOUT 600
MENU RESOLUTION 640 480
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std
LABEL linux
 MENU LABEL Try Ubuntu FS
 MENU DEFAULT
 KERNEL /casper/vmlinuz
 APPEND initrd=/casper/initrd boot=casper
LABEL linux1
 MENU LABEL Try Ubuntu FS (nomodeset)
 MENU DEFAULT
 KERNEL /casper/vmlinuz
 APPEND initrd=/casper/initrd boot=casper nomodeset
EOF

cat <<EOF | ${prefix}sed -n "w ${rootfs}/boot/iso-image/prep.sh"
#!/bin/bash

cd /boot/iso-image

grub-mkstandalone \
   --format=x86_64-efi \
   --output=isolinux/bootx64.efi \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"
# Create a FAT16 UEFI boot disk image containing the EFI bootloader
(
   cd isolinux && \
   dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
   mkfs.vfat efiboot.img && \
   LC_CTYPE=C mmd -i efiboot.img efi efi/boot && \
   LC_CTYPE=C mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)
# Create a grub BIOS image
grub-mkstandalone \
   --format=i386-pc \
   --output=isolinux/core.img \
   --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" \
   --modules="linux16 linux normal iso9660 biosdisk search" \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"
# Combine a bootable grub cdboot.img
cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img
EOF

${prefix}chmod +x ${rootfs}/boot/iso-image/prep.sh

# Hmm if this is not a hook should probably be rootshell
if [ -z "${prefix}" ] ; then
    chroot ${rootfs} /boot/iso-image/prep.sh
else
    bin/rootshell ${rootfs} /boot/iso-image/prep.sh
fi

