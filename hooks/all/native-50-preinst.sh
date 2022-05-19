#!/bin/bash

#
# Full desktop installation has packages that suck.  They have preinst
# dependencies on awk and configure dependencies on passwd, neither of
# which are installed at the point of need.
#
# This cleanup is required to get a clean desktop install but should
# not hurt server installs since everything uses base-files and mawk.
#
# Obviously it won't work on dramatically different releases so if
# you are not trying to build Ubuntu Bionic you might not want this.
#
CONF_LIST="base-files mawk"
PREINST_LIST="base-files base-passwd libc6:amd64"
dir=${1%%/}

MY_ENV="DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C"


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

if [ "$2" = "start" ]; then
    
    echo "Setting up base-files for preinst"
    for pre in $PREINST_LIST; do
	$prefix $MYENV chroot $dir /var/lib/dpkg/info/${pre}.preinst install
    done


    # This idiot package installs before shadow and fails
    echo 'lpadmin:*:101:' | $prefix tee -a ${dir}/etc/group
    echo 'cups-pk-helper:x:100:101:user for cups-pk-helper service,,,:/home/cups-pk-helper:/usr/sbin/nologin' |  $prefix tee -a ${dir}/etc/passwd

    $prefix $MYENV chroot $dir dpkg --force-configure-any --configure $CONF_LIST

elif [ "$2" = "end" ]; then
    
    echo "Attempting to fix broken packages"
    $prefix $MYENV chroot $dir dpkg --configure --pending
    
else
    
    echo "Unknown command"

fi

exit 0
