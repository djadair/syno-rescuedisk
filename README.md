# syno-rescuedisk

Tool to generate a rescue disk that can be booted in order to read
and manipulate Synology NAS drives according to:

https://kb.synology.com/en-my/DSM/tutorial/How_can_I_recover_data_from_my_DiskStation_using_a_PC

The goal is to avoid 3 issues with that procedure:

1) It works with specific versions of Ubuntu that are compatible with the btrfs-progs used on
the NAS.  The day my NAS dies I may not have an Ubuntu system or worse the ancient versions
may not even exist.

2) It requires specific kernel versions which take time to find and install -- the generic
Live CD images will not work properly.

3) It is handy to keep the OS image and backup snapshots on the same USB drive.



**WARNING:**  Make sure you test your drive. Some old systems have trouble booting GPT drives in
legacy bios mode and ancient systems can not boot GPT at all.  That said EFI boot with GPT is
likely the safest choice for future systems.

**WARNING:**  This repository contains a Makefile which is used to test the live ISO build.
Unless you are trying to build a live ISO file that is likely not what you want to use, while
it *can* also create a USB device it makes lots of default assumptions which may not match
your use case.  Please read this whole file and examine what the Makefile does before just
typeing "make".


## Setup

**NOTE:** This has only been tested when run on Ubuntu Xenial and Bionic systems installed from the
full system Live image or Jammy installed from the Canonical install disk.  Most parts should work
on any system but you will have to install all of the tools manually.  It may be particularly
challenging without a host that supports apt natively.

From a fresh install or live image of Ubuntu Bionic/Jammy you can install the pre-requisites by running:
```
sudo ./bin/installenv install
```
For the minimal set of pre-reqs, or
```
sudo ./bin/installenv install full
```
To include several personal preference items such as VNC, emacs, nfs, and the mate desktop.


If you are not running on Ubuntu then you will have to find an alternate way to install:

- apt
- multistrap  ( for dependencies, see FAQ )
- gparted ( or alternative partitioning tool )
- debconf-utils
- perl
- libconfig-auto-perl
- liblocale-gettext-perl
- libparse-debian-packages-perl
- util-linux
- coreutils
- mount
- bash

## Partitioning

Before you can run the install you must manually partition the target drive and mount
it as rootfs.  There is a suggested layout that you can create with:
```
sudo bin/partition_device  /dev/<device>
```
or using built in or your own sfdisk-like config file (see examples):
```
sudo bin/sfconv -f conf/<config> -d /dev/<device> --yesdoit
```
However partitioning is very personal -- you might want a much larger or much smaller
system or may want other volumes on your device.  I suggest that you create your partitions
manually with gparted.  At the very least examine the script and make sure it is what you
want.

**NOTE:** The installation and runtime use partition types and labels rather than device
numbers since the target may not even be a sscsi disk on the target.  Partition numbers
in the table below are for reference only, however all partitions should be within the
first 2TB and the BIOS_DATA block should be as near the front of the disk as practical.

GPT is required for large devices and EFI booting.  It is highly recommended for
forward compatiblity but may have issues for booting on some old machines.  If
you can not boot from a GPT device you may choose MBR.

**WARNING:** It may be hard to find a system that support legacy booting in the future.

GPT partition layout

| Partition | Size | Type | Name | Label | Filesystem |
| --- | --- | --- | --- | --- | --- |
| 1 | 1MB | BIOS Boot (4) | <none> | <none> |zero fill |
| 2 | 33MB | Microsoft data (11) | EFI-System | EFI-SYSTEM | fat32 |
| 3 | 2G | Linux Swap ( 19 ) | | USB_SWAP | USB_SWAP | swap |
| 4 | 2G+ | Linux Filesystem (20) | USB_ROOT | USB_ROOT | ext4 |
| 5 | <opt> | Linux Filesystem (20) | USB_DATA | USB_BTRFS_DATA | btrfs |

Choices:
- Use 10-20GB for USB_ROOT to enable installation of full desktop.  (`conf/gptlarge.conf`)
- Allocate all space to USB_ROOT to use as scratch space during recovery. (`conf/gptsmall.conf`)
- Create USB_DATA volume to use as a backup destination for synology.


The BIOS Boot partition may be 512K located at sector 1024-2047 if your disk is already formatted
and you are unable to make it partition 1.  Some tools refer to the special partition type as
`BIOS Boot` ( fdisk type 4 or sfdisk type=21686148-6449-6E6F-744E-656564454649 ). gparted refers
to it as `cleared` with a flag of `bios_boot`.  This special partition is required to enable
the installation of a legacy bios grub loader on GPT formatted drives.


MBR partition layout

| Partition | Size | Type | Name | Label | Filesystem |
| --- | --- | --- | --- | --- | --- |
| 1 | 2G+ | Linux Filesystem (20) | USB_ROOT | USB_ROOT | ext4 |
| 2 | 2G | Linux Swap ( 19 ) | | USB_SWAP | USB_SWAP | swap |
| 3 | <opt> | Linux Filesystem (20) | USB_DATA | USB_BTRFS_DATA | btrfs |

or use boot partition and let root fill the drive

| Partition | Size | Type | Name | Label | Filesystem |
| --- | --- | --- | --- | --- | --- |
| 1 | 1G | Linux Filesystem (20) | USB_BOOT | USB_BOOT | ext2 |
| 2 | 2G | Linux Swap ( 19 ) | | USB_SWAP | USB_SWAP | swap |
| 3 | -- | Linux Filesystem (20) | USB_ROOT | USB_ROOT | ext4 |

(`conf/mbrboot.conf`)
MBR does not require the two EFI partitions.  Do not create more than 3 primary partitions so
that you have one spare to use as an extended partition table.


## Installation

### Format volumes.
If you used `gparted` or `partition_device` then they will create the filesystems for you.  If you did not
then you will need to manually create the filesystems for each partition in the tables above.  Use:
```
sudo dd if=/dev/zero of=<BIOS Data Partition>
```
For the EFI Bios data and
```
sudo mkfs.<fstype>
```
for the rest.  However you may wish to skip the btrfs volume formatting and do that on your
NAS if you want to make the filesystem compatible with Synology ACL's.

### Mount volumes
You need to manually mount the rootfs and BIOS partitions.  It is also not a bad idea to wipe out existing
contents of rootfs so you get a clean install.
```
sudo mount LABEL=USB_ROOT ./rootfs
sudo rm -rf ./rootfs/*
```

Then you need to mount the bootloader volumes:

GPT:
```
sudo mkdir -p ./rootfs/boot/efi
sudo mount LABEL=EFI-SYSTEM ./rootfs/boot/efi
```

MBR ( With separate boot partition ):
```
sudo mkdir -p ./rootfs/boot
sudo mount LABEL=USB_BOOT ./rootfs/boot
```

### Run installation

Once the target is partitioned and mounted just run multistrap -f <conf/target> to perform the install.  The suggested
target is `conf/bionic-server`  Example:
```
sudo ./bin/multistrap -f conf/bionic-server -d ./rootfs
```

After the installation completes it is **VERY IMPORTANT** that you set up a user account and passwords for the
installed system.  To copy your current account use the `setup-passwords` script:
```
./bin/setup-passwords ./rootfs
```
**NOTE:** The bionic release did not support the now default "yescrypt" password format.  If your local
account uses a yescrypt password it can not be copied and you will be prompted to enter a password.

### Adjusting the install
If you want to test the installed system it has to have the proc, sys, and dev filesystems mounted.  To simplify
this and help with remembering to umount them when exiting use `bin/rootshell` :
```
sudo ./bin/rootshell ./rootfs
```

`umount` and `eject` the target and you shoud be good to go.  Be sure and test it on a machine you would
be likely to try to use.


### Live ISO build
The installed image can be used as the souce for a CASPER based Live DVD hybrid ISO image.
The majority of the work is done by the conf files ( install syslinux, isolinux ) and the
hooks/enabled/native-85-isoprep.sh script which creates the boot menus and images required
to construct the hybrid ISO.

The final construction is done by running:
```
./bin/mkiso.sh rootfs
```

Which copies the syslinux/isolinux bits out of the image, generates a squashfs copy of rootfs
and then runs xorisso to create the ISO image called "live.iso" in the top directory.

***WARNING:*** Make sure you do this AFTER running setup-passwords or configure an admin
account in some other way or you will not be able to log in to resulting live image.

For simplicity you can also use the make file to create a live image using loop devices
if you do not require USB support.
```
make CONF=conf/bionic-desktop iso; make umount
```

The full set of Makefile Parameters:

| Parameter | Use | Default |
| :--- | :--- | :--- |
| DEVICE | Block device to install | Use loop device |
| IMAGE  | Loop device backing file | scratch/disk.img |
| IMAGE_SIZE | Loop device size | 6500M |
| CONF | Multistrap conf | conf/bionic-server.conf |
| PROXY | apt-cacher-ng proxy URL | Default from /etc/apt or none |

Makefile Targets:

| Target  | Use |
| :--- | :--- |
| all  | Fake default target does nothing |
| diskonly | Build bootable disk image |
| iso | Build disk image and Live ISO |
| umount | Un-mount build FS, not done by default |
| clean | umount and remove working files |
| distclean | clean and remove live.iso |
| testbios | boot disk image with qemu (bios) |
| testefi  | boot disk image with qemu (efi) |
| testlivebios | boot live.iso with qemu (bios) |
| testliveefi | boot live.iso with qemu (efi) |

***Note:*** qemu booting can be painfully slow particulary when
run with nested emulation e.g. from a VM.  It is more suitable
for testing the boot loader than the whole image.


## Project layout

| Directory | Use  |
| :--- | :--- |
| bin | Scripts to run installation |
| conf | Config files passed to multistrap with -f |
| fake-dist | Repository used by "Programs" section. |
| hooks | Customization scripts used during multistrap process. |
| hooks/enabled | Soft links to hooks to use for build |
| image | Staging directory for ISO build |
| rootfs | Mount point for disk to be installed. |
| scratch | Working directory for loop mounted rootfs |


## FAQ:

**Why custom multistrap ?**   The default version has two annoying issues.  First it will fail if
you specify duplicate repository keyrings.  That is annoying but could be worked around by
editing the base release conf files to only define the key once.  Second several Xenial and
Bionic preinstall scripts require DPKG_MAINTSCRIPT_NAME=preinst and DPKG_MAINTSCRIPT_PACKAGE
to be specified in order to install properly.  This may or may not be fatal for your package
selections so it may or may not be required.

**Can I include  custom packages ?**  Yes, place them in "fake-repo" and then run dpkg-scanpackages.
See https://help.ubuntu.com/community/Repositories/Personal for details.  If you do this you
will either have to add your own keyring package and sign the packages or install with --no-auth.

**Why not a Live ISO ?**  The live ISO is a handy backup because a DVD makes a good archive
media.  For primary use I prefer keeping my backup data and the boot disk on the same USB drive
so that I can save backups as btrfs snapshots and access them even if I loose my NAS and the
drives.

**How do I read encrypted volumes**  The synology encrypted volumes are encrypted with ecryptfs
and may be mounted with the command:
```
mount -t ecryptfs -o ecryptfs_cipher=aes,ecryptfs_key_bytes=32,ecryptfs_passthrough=no <crypt source> <plain target>
```
You will of course require the original pass-phrase.  This requires that the source be RW
so it will not work on snapshots in @sharesnap@.  To mount those either copy them to a new
directory or create a RW snapshot with:
```
btrfs subvol snap <old ro snap> <new rw target>
```
