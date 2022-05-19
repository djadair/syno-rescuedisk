#!/bin/bash

# Multistrap hook file to enable systemd networking.
#
# By default Ubuntu uses NetworkManager but that is very large
# due to all the dependencies.  We don't want to manually configure
# networking because we don't know where this will run if it is
# required.  Easy solution -- just enable systemd to handle everything.
#
# NOTE: If you need something other than ipv4 and DHCP you may need
# to change this file or edit the network config after installation.

dir=${1%%/}
mode=$2

# run at end so we can use systemctl
[ "$mode" = "end" ] || exit 0

check_path() {
    local path=${dir}/$1
    if [ ! -d $path ] ; then
	echo "$path missing, can't set up" >&2
	exit -1
    fi
}


conf_path="etc/systemd/network"
check_path ${conf_path}

chroot ${dir} systemctl enable systemd-networkd

cat <<EOF > ${dir}/${conf_path}/20-dhcp.network
# Set up all interfaces for dhcp.
# See man systemd.network if you need something more complex
# NOTE: Newer systemd versions may have options not available here.
#

[Match]
Name=*
# MACAddress=<mac or ip>

[Network]
DHCP=ipv4
# Address=192.168.0.43
# Gateway=192.168.0.1
# DNS=192.168.0.1

[DHCP]
UseDNS=true
UseNTP=true
#UseDomains=true

EOF

