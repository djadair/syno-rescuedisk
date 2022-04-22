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


**NOTE:** This has only been tested when run on Ubuntu Xenial and Bionic systems instaled from the
full system Live image.  Most parts should work on any system but you will have to install
all of the tools manually.  It may be particularly challenging without a host that supports apt
natively.

**WARNING:**  Make sure you test your drive. Some old systems have trouble booting GPT drives in
legacy bios mode and ancient systems can not boot GPT at all.  That said EFI boot with GPT is
likely the safest choice for future systems.


## Partitioning


## Installation


## Project layout

| Directory | Use  |
| :--- | :--- |
| bin | Scripts to run installation |
| conf | Config files passed to multistrap with -f |
| hooks | Customization scripts used during multistrap process. |
| rootfs | Mount point for disk to be installed. |
| fake-dist | Repository used by "Programs" section. |


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

**Why not a Live ISO ?**  Because I don't know how to do that without lorax.  Seriously I like
keeping my backup data and the boot disk on the same USB drive but ISO would be ok if
I knew how to create one.
