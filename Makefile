
# Make file to create disk or DVD image.

# This is mostly for testing and keeping track of commands
# required to run build.  Remember we are partitioning and formatting
# an actual hard drive so really bad stuff could happen fast.
# Consider just running the steps manually so you can be SURE you
# are operating on the correct device.

# If you have a specific build the easiest way to use is to
# create a second makefile  and make -c this file.

# BIG NOTE:  This makefile is not 100% flexible with disk layouts.
#            Specifically it depends on USB_ROOT and EFI-SYSTEM
#            labels.  If you change those change below.

#
# Paramters:
#    DEVICE	Block device to install.  	Loop device used if not specified.
#    IMAGE	Backing file for loop.    	Default scratch/disk.img
#    IMAGE_SIZE Size for image file. 		Default 6500M.
#    CONF       Multistrap config to install. 	Default conf/bionic-server.conf
#    PROXY      apt-cacher-ng proxy URL.	Default from /etc/apt config.
#
# Targets:
#    all        Fake target does nothing.
#    diskonly   Build bootable disk image.
#    iso        Build Live DVD ISO file.
#
#    umount     Un-mount built FS, by default it is left mounted.
#    clean      umount and remove working files.
#    distclean  clean and remove live.iso
#
#    testbios       Boot disk image with qemu (bios boot)
#    testefi        Boot disk image with qemu (efi boot)
#    testlivebios   Boot live image with qemu (bios boot)
#    testliveefi    Boot live image with qemu (efi boot)
#
# Example:  make CONF=conf/bionic-desktop iso; make umount

PWD := $(shell pwd)
TOOL_DIR := $(PWD)/bin
SCRATCH_DIR := $(PWD)/scratch
ROOT_DIR := $(PWD)/rootfs
IMAGE_DIR := $(PWD)/image
SU := sudo --preserve-env=http_proxy

# Default to non-graphic config
CONF := conf/bionic-server.conf

# Scratch file for loop device.
IMAGE := $(SCRATCH_DIR)/disk.img
IMAGE_SIZE := 6500M


# If PROXY not specified check if one is present in local apt config.
PROXY := $(shell grep "Acquire::http::Proxy" /etc/apt/apt.conf.d/* | awk -F "\"" '{print $$2}' | egrep "^http*://")


ifneq ($(strip $(PROXY)),)
$(info setting proxy $(PROXY))
http_proxy := $(PROXY)
export http_proxy
endif

# Primary targets
.PHONY : all diskonly iso
# Internal build steps
.PHONY : loop part mount install passwd
# Clean targets
.PHONY : umount clean distclean
# Test boot
.PHONY : testbios testefi testhd
all:
	$(SU) env | grep proxy
	@echo "Use diskonly or iso target to build"

# This must be deferred if we need it it is not set yet.
# NOTE:  While this would fix the race condition in sfdisk.sh
#        there is a catch-22 since from command line user does
#        not know device has changed.
DEVICE ?= $(shell losetup -j $(IMAGE) | cut -f1 -d:)

ifeq ($(strip $(DEVICE)),)

part: loop

else

part: $(DEVICE)

endif



$(IMAGE): Makefile
	$(SU) rm -f $@
	$(SU) truncate -s $(IMAGE_SIZE) $@


loop: $(IMAGE)
	$(SU) losetup -f $(IMAGE)


part:
	$(SU) $(TOOL_DIR)/partition_device $(DEVICE)

# Just in case dev system is using conflicting labels.  Note this
# is deferred until after partitioning.
ROOT_UUID = $(shell $(SU) blkid --probe $(DEVICE)* | \
	grep USB_ROOT | egrep -o ' UUID=[^ ]*')
SYS_UUID  = $(shell $(SU) blkid --probe $(DEVICE)* | \
	grep EFI-SYSTEM | egrep -o ' UUID=[^ ]*')

INSTALL_DEP := $(shell mount | grep -q "$(ROOT_DIR) " || echo mount)

mount: part
	$(info device: $(DEVICE) root: $(ROOT_UUID))
	$(SU) mount $(ROOT_UUID)  $(ROOT_DIR)
	$(SU) mkdir -p $(ROOT_DIR)/boot/efi
	$(SU) mount $(SYS_UUID) $(ROOT_DIR)/boot/efi

install: $(INSTALL_DEP)
	$(SU) $(TOOL_DIR)/multistrap -f $(CONF) -d $(ROOT_DIR)


# Non-phony version so we can partially build
$(ROOT_DIR)/etc/passwd: $(INSTALL_DEP)
	$(SU) $(TOOL_DIR)/multistrap -f $(CONF) -d $(ROOT_DIR)


# This is NOT SU -- requires a valid user ID
passwd: $(ROOT_DIR)/etc/passwd
	$(TOOL_DIR)/setup-passwords $(ROOT_DIR)

diskonly: passwd

live.iso: passwd
	$(SU) rm -rf $(IMAGE_DIR)
	$(SU) rm -f live.iso
	mkdir $(IMAGE_DIR)
	$(TOOL_DIR)/mkiso.sh $(ROOT_DIR) $(IMAGE_DIR)

iso: live.iso

umount:
	$(SU) umount $(ROOT_DIR)/boot/efi 2>/dev/null || true
	$(SU) umount $(ROOT_DIR) 2>/dev/null || true

# Don't bother cleaning physical disk -- it is wiped
# when re-partitioned.
clean: umount
	[ -n "$(DEVICE)" ] && losetup $(DEVICE) 2>&1 >/dev/null && $(SU) losetup -d $(DEVICE) || true
	$(SU) rm -rf $(IMAGE_DIR)
	$(SU) rm -f $(IMAGE)

distclean: clean
	$(SU) rm -f live.iso

# If host is a VM these are incredibly painful with desktop image.
# Either skip testing or stick with server image.
testlivebios: live.iso
	$(SU) qemu-system-x86_64 -boot d -cdrom live.iso -m 1g

testliveefi:  live.iso
	$(SU) qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd -cdrom live.iso -m 1g

testbios:   umount
	$(SU) qemu-system-x86_64 -boot d -hda $(DEVICE) -m 1g

testefi:    umount
	$(SU) qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd -hda $(DEVICE) -m 1g
