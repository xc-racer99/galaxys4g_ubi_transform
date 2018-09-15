#!/tmp/busybox sh
#
# Universal Updater Script for Samsung Galaxy S Phones
# (c) 2011 by Teamhacksung
# GSM version
#

check_mount() {
    if ! /tmp/busybox grep -q $1 /proc/mounts ; then
        /tmp/busybox mkdir -p $1
        /tmp/busybox umount -l $2
        if ! /tmp/busybox mount -t $3 $2 $1 ; then
            /tmp/busybox echo "Cannot mount $1."
            exit 1
        fi
    fi
}

set_log() {
    rm -rf $1
    exec >> $1 2>&1
}

# ui_print
OUTFD=$(\
    /tmp/busybox ps | \
    /tmp/busybox grep -v "grep" | \
    /tmp/busybox grep -o -E "/tmp/updater .*" | \
    /tmp/busybox cut -d " " -f 3\
);

if /tmp/busybox test -e /tmp/update_binary ; then
    OUTFD=$(\
        /tmp/busybox ps | \
        /tmp/busybox grep -v "grep" | \
        /tmp/busybox grep -o -E "update_binary(.*)" | \
        /tmp/busybox cut -d " " -f 3\
    );
fi

ui_print() {
    if [ "${OUTFD}" != "" ]; then
        echo "ui_print ${1} " 1>&"${OUTFD}";
        echo "ui_print " 1>&"${OUTFD}";
    else
        echo "${1}";
    fi
}

# warning repartitions
warn_repartition() {
    if ! /tmp/busybox test -e /tmp/.accept_wipe ; then
        /tmp/busybox touch /tmp/.accept_wipe;
        ui_print ""
        ui_print "========================================"
        ui_print "ATTENTION"
        ui_print ""
        ui_print "This VERSION uses an incompatible"
        ui_print "partition layout"
        ui_print "Your device will be wiped completely"
        ui_print "So, backup everything then just"
        ui_print "run this zip again to confirm install"
        ui_print ""
        ui_print "ATTENTION"
        ui_print "========================================"
        ui_print ""
        exit 9
    fi
    /tmp/busybox rm -fr /tmp/.accept_wipe;
}

set -x
export PATH=/:/sbin:/system/xbin:/system/bin:/tmp:$PATH

# warn repartition
warn_repartition

# make sure sdcard is mounted
check_mount /sdcard /dev/block/mmcblk0p1 vfat

# everything is logged into /sdcard/aries_ubi_update.log
set_log /sdcard/aries_mainline_update.log

# make sure efs is mounted
if /tmp/busybox test -e /dev/block/mtdblock0 ; then
    check_mount /efs /dev/block/mtdblock5 yaffs2
else
    check_mount /efs /dev/block/stl3 rfs
fi

# create a backup of efs
if /tmp/busybox test -e /sdcard/backup/efs.img ; then
    /tmp/busybox mv /sdcard/backup/efs.img /sdcard/backup/efs-$$.img
    /tmp/busybox mv /sdcard/backup/efs.img.md5 /sdcard/backup/efs-$$.img.md5
fi
/tmp/busybox rm -f /sdcard/backup/efs.img
/tmp/busybox rm -f /sdcard/backup/efs.img.md5

/tmp/busybox mkdir -p /sdcard/backup

/tmp/busybox chmod +x /tmp/mkfs.jffs2
/tmp/mkfs.jffs2 -e 256 --with-xattr -d /efs -o /sdcard/backup/efs.img

# Now we checksum the file. We'll verify later when we do a restore
cd /sdcard/backup/
/tmp/busybox md5sum -t efs.img > efs.img.md5

# create a JFFS2 img of the radio
/tmp/mkfs.jffs2 -e 256 --with-xattr -d /tmp/radio -o /sdcard/backup/radio.img
/tmp/busybox md5sum -t radio.img > radio.img.md5

# copy u-boot, recovery image to SD
/tmp/busybox cp /tmp/u-boot.bin /sdcard/backup
/tmp/busybox cp /tmp/recovery.img /sdcard/backup

# write new kernel to boot partition
# this is a specially formulated kernel that restores
# the efs.img and radio.img
/tmp/busybox chmod +x /tmp/flash_image
/tmp/flash_image boot /tmp/zImage
if [ "$?" != "0" ] ; then
    /tmp/busybox echo "Failed to write kernel to boot partition"
    exit 3
fi
/tmp/busybox echo "Successfully wrote kernel to boot partition"
# Also write it to u-boot partition, if present
/tmp/flash_image u-boot /tmp/zImage
if [ "$?" != "0" ] ; then
    /tmp/busybox echo "Failed to write kernel to u-boot partition"
fi

/tmp/busybox sync
/tmp/busybox umount /sdcard
/tmp/busybox sleep 10

/sbin/reboot
