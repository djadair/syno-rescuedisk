#!/bin/bash

# Multistrap hook file to mount native directories required for clean
# installation.

dir=${1%%/}
mode=$2

# we only process start so unmount can be at end
[ "$mode" = "start" ] || exit 0

check_path() {
    local path=${dir}/$1
    if [ ! -d $path ] ; then
	echo "$path missing, can't set up" >&2
	exit -1
    fi
}

check_path ""
check_path "proc"
check_path "sys"
check_path "dev"

mount -t proc proc $dir/proc
mount -t sysfs sys $dir/sys
mount -o bind /dev $dir/dev
mount -t devpts devpts $dir/dev/pts

# Fixup required for /var/run to let preinst work
[ -h $dir/var/run ] || rm -rf $dir/var/run/*
