#!/bin/bash
ME=`basename $0`

##########################################################################
#   Resize disk in an ova
#
#   Background: 
#       ova files released usually have minimal disk requirements.
#       This script uses VBoxManage to resize it internally, before
#       a VM is created. After VM starts, re-partitioning may still
#       be needed in order to make full use of the disk size.
#
#       cloud images may not have a swap space, so partitioning may
#       not be required.
##########################################################################

usage() {
    cat <<EOF

$ME /path/to/ova [ new-disk-size ]

1st arg     location to ova image
2nd arg     optional disk size in MB (default is 51200, for 50G)

Note: making the size smaller than the size in the ova will be nothing but trouble

EOF
}

DEBUG=$$
if [ "$1" = "-d" ]; then
    DEBUG=debug
    shift
fi

if [ $# -lt 1 -o "$1" = "-h" -o "$1" = "--help" -o ! -s "$1" ]; then
    usage
    exit 1
fi

declare -i DISKSIZE=${2:-51200}
OVADIR="$( cd "$( dirname "$1" )" && pwd )"
OVA=$(basename $1)
pushd $OVADIR > /dev/null
if [ -s ${OVA}.bak ]; then
    printf "\nWARNING! ${OVA}.bak already present, so leaving it\n"
    rm -f $OVA
else
    mv $OVA ${OVA}.bak
fi
TMPDIR=${OVADIR}/${OVA}${DEBUG}
VMDK=x
CLONE=cloned.vdi

cleanup() {
    trap - 0 1 2 3 15 21 22
    if [ ! -s "${OVADIR}/$OVA" ]; then
        printf "\nno results, restoring original\n"
        mv ${OVADIR}/${OVA}.bak ${OVADIR}/${OVA}
        if [ -s ${TMPDIR}/${VMDK} ]; then
            VBoxManage closemedium disk $VMDK --delete 
        fi
        if [ -s ${TMPDIR}/${CLONE} ]; then
            VBoxManage closemedium disk $CLONE --delete 
        fi
    else
        printf "\n${OVADIR}/${OVA} re-sized\n"
        if [ "$DEBUG" != "debug" ]; then
            rm -f ${OVADIR}/${OVA}.bak
        else
            printf "\nDEBUG: leaving original ${OVADIR}/${OVA}.bak intact\n"
        fi
    fi
    if [ "$DEBUG" != "debug" ]; then
        rm -rf $TMPDIR
    else
        printf "\nDEBUG: leaving working directory $TMPDIR intact\n"
    fi
}

trap cleanup 0 1 2 3 15 21 22

rm -rf $TMPDIR
mkdir $TMPDIR
pushd $TMPDIR > /dev/null
printf "\nExtracting ova content\n"
tar xf $OVADIR/${OVA}.bak 2>/dev/null || { printf "\nova file does not appear to be valid\n"; exit 1; }
VMDK=$(ls *vmdk 2>/dev/null) || { printf "\nova file does not appear to be valid\n"; exit 1; }
printf "\nConverting $VMDK to vdi format\n"
ls -hl $VMDK
VBoxManage clonemedium $VMDK $CLONE --format vdi || exit
printf "\nRe-size vdi to $DISKSIZE\n"
VBoxManage modifymedium $CLONE --compact --resize $DISKSIZE || exit
ls -hl $CLONE
VBoxManage closemedium disk $VMDK --delete || exit
printf "\nConvert to vmdk format needed for ova\n"
VBoxManage clonemedium $CLONE $VMDK --format vmdk || exit
ls -hl $VMDK
VBoxManage closemedium disk $CLONE --delete || exit
printf "\nRe-create ova\n"
set $(sha256sum $VMDK) x x
SUM=$1
sed -i "/vmdk/s/= .*/= $SUM/" *mf
tar cf $OVADIR/${OVA} * || exit
VBoxManage closemedium disk $VMDK --delete || exit
set $(sha256sum $OVADIR/${OVA}) x x
cat <<EOF

##########################################################################

source_path=$OVADIR/${OVA}
checksum=$1

##########################################################################

EOF

