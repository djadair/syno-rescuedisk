#!/bin/bash

# We need to block initscripts from running "start" operations
# inside the chroot.  This causes two problems:
#  rare:  daemon starts and will mess up host. ( most smart enough not to )
#  common: packages assumes running system and start fails

# This really should not be required since using start is deprecated
# but ironically the upgrade logic crams it back in several key packages.

dir=${1%%/}



# Just change all start requests to defaults
setup_fake_update() {
    orig_prog=$(chroot $dir which update-rc.d)

    if [ "$orig_prog" = "/usr/sbin/update-rc.d" ] ; then
	mv ${dir}${orig_prog} ${dir}${orig_prog}.REAL
	cat <<EOF > ${dir}${orig_prog}
#!/bin/bash

if [ "\$2" = "start" ] ; then
  ${orig_prog}.REAL \$1 defaults
else
  ${orig_prog}.REAL \$@
fi

true
EOF

	chmod +x ${dir}${orig_prog}
    else
	echo "Could not find update-rc.d" >&2
	exit -1
    fi
}


remove_fake_update() {
    orig_prog=$(chroot $dir which update-rc.d)

    if [ -x ${dir}${orig_prog}.REAL ] ; then
	rm ${dir}${orig_prog}
	mv ${dir}${orig_prog}.REAL ${dir}${orig_prog}
    else
	echo "Could not restore ${orig_prog}.REAL"
	exit -1
    fi
}

if [ "$2" = "start" ] ; then
    setup_fake_update
elif [ "$2" = "end" ] ; then
    remove_fake_update
else
    echo "Unknown command"
fi

