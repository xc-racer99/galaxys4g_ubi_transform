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
        ui_print "Your SD card will be wiped completely"
        ui_print "So, make your backups then just"
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

# make sure there's not 3 partitions, we can't handle that many
if /tmp/busybox test -e /dev/block/mmcblk0p3 ; then
    ui_print "You have 3+ partitions"
    ui_print "Please go down to 2 or fewer"
    ui_print "and the run this again"
    exit 4
fi

# check if we're running on a bml or mtd device
if /tmp/busybox test -e /dev/block/bml7 || [ "$(/tmp/busybox cat /sys/class/mtd/mtd1/name)" != "ramdisk" ] ; then
    # we're running on a bml or an old mtd device

    # warn repartition
    warn_repartition

    # make sure sdcard is mounted
    check_mount /sdcard /dev/block/mmcblk0p1 vfat

    # everything is logged into /sdcard/aries_ubi_update.log
    set_log /sdcard/aries_ubi_update.log

    # copy ramdisk to sdcard
    /tmp/busybox cp /tmp/ramdisk.cpio /sdcard

    # make sure efs is mounted
    if /tmp/busybox test -e /dev/block/mtdblock0 ; then
        check_mount /efs /dev/block/stl3 yaffs2
    else
        check_mount /efs /dev/block/stl3 rfs
    fi

    # create a backup of efs
    if /tmp/busybox test -e /sdcard/backup/efs.tar ; then
        /tmp/busybox mv /sdcard/backup/efs.tar /sdcard/backup/efs-$$.tar
        /tmp/busybox mv /sdcard/backup/efs.tar.md5 /sdcard/backup/efs-$$.tar.md5
    fi
    /tmp/busybox rm -f /sdcard/backup/efs.tar
    /tmp/busybox rm -f /sdcard/backup/efs.tar.md5

    /tmp/busybox mkdir -p /sdcard/backup

    cd /efs
    /tmp/busybox tar cf /sdcard/backup/efs.tar *

    # Now we checksum the file. We'll verify later when we do a restore
    cd /sdcard/backup/
    /tmp/busybox md5sum -t efs.tar > efs.tar.md5

    # write new kernel to boot partition
    /tmp/busybox chmod +x /tmp/flash_image
    /tmp/flash_image boot /tmp/boot.img
    if [ "$?" != "0" ] ; then
        /tmp/busybox echo "Failed to write kernel to boot partition"
        exit 3
    fi
    /tmp/busybox echo "Successfully wrote kernel to boot partition"
    /tmp/busybox sync
    /tmp/busybox umount /sdcard
    /tmp/busybox sleep 10

    /sbin/reboot
    exit 0
elif /tmp/busybox test -e /dev/block/mtdblock0 ; then
    # we're running on an mtd (new) device

    # make sure sdcard is mounted
    check_mount /sdcard /dev/block/mmcblk0p1 ext4

    # everything is logged into /sdcard/aries_mtd.log
    set_log /sdcard/aries_mtd.log

    # write new kernel to boot partition
    /tmp/busybox chmod +x /tmp/flash_image
    /tmp/flash_image boot /tmp/boot.img
    if [ "$?" != "0" ] ; then
        /tmp/busybox echo "Failed to write kernel to boot partition"
        exit 2
    fi
    /tmp/busybox umount /sdcard
    exit 0
fi
