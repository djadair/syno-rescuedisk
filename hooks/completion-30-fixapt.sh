#!/bin/bash

# Multistrap hook file to clean up apt keys after installation.
#
# This should run as a completion hook since it is not native specific
# and wants to run AFTER the runtime apt config.
#
#  Hook order:
#     < download >
#    setupscript
#    download-xxx  root_dir
#    native-xxx    root_dir start
#     < pre-init >
#     < dpkg --configure >
#     < re-install >
#    native-xxx    root_dir end
#     < extra >
#     < copy configsh to root >
#     < runtime apt setup >
#    completion-xxx root_dir
#

dir=${1%%/}

change_mode() {
    file=${dir}/$2
    mode=$1
    [ -f "$file" ] && chmod ${mode} ${file}
}

# This must be world-read for apt to run post-install.
change_mode 644 etc/apt/trusted.gpg.d/trustdb.gpg
# TBD -- may want to just delete this one
change_mode 644 etc/apt/trusted.gpg.d/multistrap.gpg

# get rid of backup files
rm -f ${dir}/etc/apt/trusted.gpg.d/*~

true

