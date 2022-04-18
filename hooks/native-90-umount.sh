#!/bin/bash

# Multistrap hook file to mount native directories required for clean
# installation.

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

check_path "proc"
check_path "sys"
check_path "dev"

umount $dir/proc
umount $dir/sys
umount $dir/dev
