#!/bin/bash

# sfdisk does not allow long format partition definitions
# without a valid "start=" which is a PITA to calculate.
# Was broken on purpose and refused to fix hence this cruft.

# input file is a normal sfdisk config file with additions to
# work around the requirement for a valid start= by calculating
# them based on 1MB alignment to the previous partision.

# Also supports formatting and labeling the generated partitions
# since that is pretty much always what is desired.

# Expansions:
#   SECTOR_SIZE(<count>*<units>) :> $(( ($expr) / logical sector size ))
#      valid units:  KB, MB, GB
#   ALIGN_SECTOR :> prior sector start + size rounded up to 1MB
#   FORMAT( fstype ) :> <removed>, partition will be formatted.
#      valid fstype: zero, swap or anything with mkfs.$fstype
#   LABEL( label ) :> <removed>, fs will be labeled.
#
# Basically this works around sfdisk refusing to allow missing start=
# when long format is used to include partition names.
#
# Comments only allowed with # in first column

MB=$((1024 * 1024))
GB=$((1024 * 1024 * 1024))
KB=1024

help() {
    echo "syntax: $0 -f <config> -d <device> [ --dry-run ]"
    echo "        sudo $0 -f <config> -d <device> --yesdoit"
    echo
    echo "The first format will run as display only."
    echo "The second format will partition your drive."
    echo
    echo "Options:"
    echo "  -h --help    : print this message."
    echo "  -v           : verbose print extra info."
    echo "  -f <config>  : partition map to expand."
    echo "  -d <dev>     : block device to partition."
    echo "  -n --dry-run : just print, don't partition (default)"
    echo "  --yesdoit    : partition and format"
    echo
    echo "For safety this command will not change your drives"
    echo "unless --yesdoit is specified.  You have been warned."
    echo "Examine output carefully to make sure you are operating"
    echo "on the correct disk."
    exit 1
}

fail() {
    echo "Error: $@"
    echo
    help
}

verbose() {
  [ -n "${a_verbose}" ] && echo $@ >&2
}

safe_command() {
    if [ -z "${a_yesdoit}" ] ; then
	echo $@
    else
	$@
	res=$?
	if [ ! "$res" = "0" ] ; then
	    echo "Error: Command $@ returned $res"
	    exit 1
	fi
    fi
}

# Display our hide command output based on verbose
quiet() {
  [ -n "${a_verbose}" ] && echo -n ">&2" || echo -n "2>&1 > /dev/null"
}

# We already require util-linux so might as well have long args.
# for portability ditch --dev, --file and make "-:" aka "--" a short opt
# aka use bash getopts built-in.
while getopts  "hvn-:d:f:" arg ; do
  case "${arg}" in
    "h" ) help && exit ;;
    "v" ) a_verbose=1 && echo "found verbose" ;;
    "n" ) a_dryrun=1 && verbose "found dry-run" ;;
    "d" ) a_dev=$OPTARG && verbose "found device: $OPTARG" ;;
    "f" ) a_conf=$OPTARG && verbose "found input file: $OPTARG" ;;
    "-" )
	case "${OPTARG}" in
	    "help" )
		help && exit ;;
	    "yesdoit" )
		a_yesdoit=1 && verbose "found yes" ;;
	    "dry-run" )
		a_dryrun=1 && verbose "found dry-run" ;;
	    * )
		echo "Invalid option --$OPTARG"
		help && exit 1 ;;
	esac
	;;    
    "?" ) echo "Unknown arg $OPTARG" && help $0 && exit ;;
  esac
done

if [ -n "$a_dryrun" ] ; then
    verbose "dry-run mode overrides yesdoit"
    unset a_yesdoit
fi

[ -n "$a_conf" -a -n "$a_dev" ] || fail "-f and -d are mandatory"
[ -f "$a_conf" ] || fail "No config file found."
[ -b "$a_dev" ]  || fail "$a_dev is not a block device."

t=$( mount | grep $a_dev)
if [ -n "$t" ] ; then
    echo "$a_dev appears to be in use"
    echo $t
    fail "Can not partition active drive"
fi

dtype=$(lsblk -o type $a_dev | awk -F" " 'FNR == 2 { print $1 }')
[ "${dtype}" = "disk" ] || [ "${dtype}" = "loop" ] || fail "$a_dev must be whole disk"

if [ "${dtype}" = "loop" ] ; then
    if ! losetup $a_dev ; then
	fail "$a_dev is loop but not loop dev"
    fi
fi	

[ -z "${a_yesdoit}" -o $(id -u) -eq 0 ] || fail "sudo required to partition"
 

sector_size=$(lsblk ${a_dev} -o LOG-Sec | awk -F" " 'FNR == 2 { print $1 }')
sm1=$((sector_size -1))
mbm1=$((MB -1))

if ! [ x"${sector_size}" = "x512" -o x${sector_size} = "x4096" ] ; then
    echo "Sector size $sector_size does not seem correct, aborting"
    exit -1
fi


sector() {
    local t=$1
    echo $(((t + sm1) / sector_size))
}

align_bytes() {
    local t=$1
    t=$(((t + mbm1) / MB))
    echo $((t * MB))
}

align_sector() {
    local t=$1
    t=$(align_bytes $((t * sector_size)))
    echo $(sector $t)
}

# expand SECTOR_SIZE( expr )
check_sector() {
    local t=$1
    expr=$(echo $t | sed -n -e 's/.*SECTOR_SIZE(\([^)]*\).*/\1/p')
    if [ -n "${expr}" ] ; then
	val=$(( ($expr) / sector_size ))
	echo $t | sed -e "s/SECTOR_SIZE([^)]*)/$val/"
    else
	echo $t
    fi
}

# expand ALIGN_SECTOR
check_align() {
    local t=$1
    local targ=$2
    local next_sector=$(align_sector $targ)

    echo $t | sed -e "s/ALIGN_SECTOR/$next_sector/"
}

# Remove fake commands from first pas
check_internal() {
    local t=$1
    if [ ! x"$t" = x"${t##FORMAT}" ] ; then
	t=""
    elif [ ! x"$t" = x"${t##LABEL}" ] ; then
	t=""
    fi
    echo $t
}

pfile=$(mktemp --tmpdir tmp.sfdisk.XXXXXXXX)
verbose "Temp file is $pfile"

last_start=0
last_size=0
cat ${a_conf} | grep -v "^#" | tr -d " " | while read line ; do
    sep=" "
    line=$(echo $line | tr "," " ")
    for item in $line ; do
	item=$(check_sector $item)
	item=$(check_align  $item $(( last_start + last_size )) )
	item=$(check_internal $item)
	if [ -n "${item}" ] ; then
	    echo -n "${sep}${item}"
	    sep=", "
	    t="${item##start=}"
	    if [ ! "$t" = ${item} ] ; then
		last_start=$t
	    fi
	    t="${item##size=}"
	    if [ ! "$t" = ${item} ] ; then
		last_size=$t
	    fi
	fi
    done
    echo ""
done | tee $pfile


# re-direction won't work in safe_command
if [ -z "${a_yesdoit}" ] ; then
    echo "sfdisk -w always -W always ${a_dev} < $pfile"
else
    sfdisk -w always -W always ${a_dev} < $pfile
    echo "waiting for new partitions"
    sleep 5
    if [ "${dtype}" = "loop" ] ; then
	# loop device requires teardown and re-create
	img=$(losetup $a_dev | sed -e 's%[^(]*(\([^)]*\))%\1%')
	[ -n "$img" ] || fail "Could not find loop image"
	# This is a tough choice.  Dumb scripts are going
	# to be flummoxed when we re-probe.  To avoid problems
	# keep track of backing file and use losetup -j $img
	# to find correct device after partitioning.
	#
	# Linux as of 4.15 does not provide any atomic way to
	# probe a loop device for new partitions.
	losetup -d $a_dev
	if ! losetup -P --show $a_dev $img ; then
	    echo "WARNING: Lost control of $a_dev"
	    a_dev=$(losetup -P --show -f $img)
	    echo "New device is : $a_dev"
	fi
    fi
    kpartx -s ${a_dev}
fi

[ -n "${a_verbose}" ] || rm $pfile

if [ -z "$a_yesdoit" ] ; then
    echo "WARNING: partition devices may not be corect in dry-run mode" >&2
    echo "will default to ${a_dev}<partno>." >&2
fi

# Check for FORMAT(), all partitions must have a type
export partno=1
cat ${a_conf} | grep "type=" | tr -d " " | while read line ; do
    echo "formatting partition $partno"
    p=$(lsblk -l ${a_dev} | awk "FNR == $(( 2 + partno )) { print \$1 }")
    if [ -n "$p" ] ; then
	partdev=/dev/${p}
    else
	partdev=${a_dev}${partno}
    fi
    (( partno++ ))
    fs=$(echo $line | sed -n -e 's/.*FORMAT([ ]*\([^) ]*\).*/\1/p')
    label=$(echo $line | sed -n -e 's/.*LABEL([ ]*\([^)]*\).*/\1/p')
    label=${label%% }
    if [ -n "$fs" ] ; then
	verbose "Formatting $partdev as $fs"
	case $fs in
	    "zero")
		echo "Clearing $partdev"
		if [ -n "${a_yesdoit}" ] ; then
		    dd if=/dev/zero of=$partdev 2>&1 >/dev/null
		fi
		;;

	    "swap")
		safe_command "wipefs -a $partdev"
		safe_command "mkswap ${label:+--label $label} $partdev"
		;;
	
	    "fat32"|"vfat") 
		safe_command "wipefs -a $partdev"
		safe_command  "mkfs.vfat ${label:+-n $label} $partdev"
		;;
	    "btrfs" )
		safe_command "wipefs -a $partdev"
		safe_command "mkfs.btrfs ${label:+-L $label} $partdev"
		;;
	    * )
		if [ -z "$(which mkfs.$fs)" ] ; then
		    fail "Don't know how to make $fs"
		else
		    safe_command "wipefs -a $partdev"
		    safe_command "mkfs.$fs ${label:+-L $label} $partdev"
		fi
		;;
	esac
    fi
done
