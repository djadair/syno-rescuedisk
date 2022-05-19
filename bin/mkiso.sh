#!/bin/bash
set -x
# Adapted from: https://itnext.io/how-to-create-a-custom-ubuntu-live-from-scratch-dd3b3f213f81
# Author: Marcos Vallim
# following is in chroot

rootfs=$(readlink -f $1)
image=${2:-image}
if [ -z "${1}" ] || [ ! -d "${rootfs}" ] ; then
    echo "Can not locate rootfs"
    echo "syntax $0 <rootfs_dir>"
    exit 1
fi

##  Now on main system
# Create directories
mkdir -p ${image}/{casper,isolinux,install}

# Copy kernel images
sudo cp ${rootfs}/boot/vmlinuz-**-**-generic ${image}/casper/vmlinuz
sudo cp ${rootfs}/boot/initrd.img-**-**-generic ${image}/casper/initrd

# Copy memtest86+ binary (BIOS)
sudo cp ${rootfs}/boot/memtest86+.bin ${image}/install/memtest86+

#  Create base point access file for grub
touch ${image}/ubuntu

# Grab grub and efi stuff from image.
sudo cp -p ${rootfs}/boot/iso-image/isolinux/* ${image}/isolinux

# Generate manifest
sudo chroot ${rootfs} dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee ${image}/casper/filesystem.manifest
sudo cp -v ${image}/casper/filesystem.manifest ${image}/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' ${image}/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' ${image}/casper/filesystem.manifest-desktop
sudo sed -i '/discover/d' ${image}/casper/filesystem.manifest-desktop
sudo sed -i '/laptop-detect/d' ${image}/casper/filesystem.manifest-desktop
sudo sed -i '/os-prober/d' ${image}/casper/filesystem.manifest-desktop

# Create squashfs
sudo mksquashfs ${rootfs} ${image}/casper/filesystem.squashfs

# Write the filesystem.size
printf $(sudo du -sx --block-size=1 ${rootfs} | cut -f1) > ${image}/casper/filesystem.size

# Create file ${image}/README.diskdefines
cat <<EOF > ${image}/README.diskdefines
#define DISKNAME  Syno Rescue Live
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

# Create iso from the image directory using the command-line
#sudo xorriso \
#   -as mkisofs \
#   -iso-level 3 \
#   -full-iso9660-filenames \
#   -volid "Ubuntu from scratch" \
#   -output "../ubuntu-from-scratch.iso" \
#   -eltorito-boot boot/grub/bios.img \
#      -no-emul-boot \
#      -boot-load-size 4 \
#      -boot-info-table \
#      --eltorito-catalog boot/grub/boot.cat \
#      --grub2-boot-info \
#      --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
#   -eltorito-alt-boot \
#      -e EFI/efiboot.img \
#      -no-emul-boot \
#   -append_partition 2 0xef isolinux/efiboot.img \
#   -m "isolinux/efiboot.img" \
#   -m "isolinux/bios.img" \
#   -graft-points \
#      "/EFI/efiboot.img=isolinux/efiboot.img" \
#      "/boot/grub/bios.img=isolinux/bios.img" \
#      "."

# Alternative way, if previous one fails, create an Hybrid ISO
# Create a ISOLINUX (syslinux) boot menu

# Include syslinux bios modules
sudo cp ${rootfs}/usr/lib/ISOLINUX/isolinux.bin ${image}/isolinux/ 
sudo cp ${rootfs}/usr/lib/syslinux/modules/bios/* ${image}/isolinux/
sudo mkdir -p ${image}/EFI/boot
sudo cp ${image}/isolinux/efiboot.img ${image}/EFI/boot/

# Generate md5sum.txt
sudo /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > ${image}/md5sum.txt)"

# Create iso from the image directory
sudo xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "UBUNTU_LIVE" \
   -output "live.iso" \
 -isohybrid-mbr ${rootfs}/usr/lib/ISOLINUX/isohdpfx.bin \
 -eltorito-boot \
     isolinux/isolinux.bin \
     -no-emul-boot \
     -boot-load-size 4 \
     -boot-info-table \
     --eltorito-catalog isolinux/isolinux.cat \
 -eltorito-alt-boot \
     -e EFI/boot/efiboot.img \
     -no-emul-boot \
     -isohybrid-gpt-basdat \
 -append_partition 2 0xef ${image}/EFI/boot/efiboot.img \
   "${image}"
