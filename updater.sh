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

format_partitions() {
    /lvm/sbin/lvm lvcreate -L ${SYSTEM_SIZE}B -n system lvpool
    /lvm/sbin/lvm lvcreate -l 100%FREE -n userdata lvpool

    # format data (/system will be formatted by updater-script)
    /tmp/make_ext4fs -b 4096 -g 32768 -i 8192 -I 256 -l -16384 -a /data /dev/lvpool/userdata

    # unmount and format datadata
    /tmp/busybox umount -l /datadata
    /tmp/erase_image datadata
}

set -x
export PATH=/:/sbin:/system/xbin:/system/bin:/tmp:$PATH

SYSTEM_SIZE='629145600' # 600M
MMC_PART='/dev/block/mmcblk0p2'

# warn repartition
warn_repartition

# make sure sdcard is mounted
#check_mount /sdcard /dev/block/mmcblk0p1 vfat

# everything is logged into /sdcard/aries_ubi_update.log
#set_log /sdcard/aries_ubifs_update.log

ubiformat /dev/mtd/mtd3 -y
ubiattach -p /dev/mtd/mtd3

# Create UBI volumes for radio, efs, cache, system, datadata
ubimkvol /dev/ubi0 -s 19712KiB -N radio
ubimkvol /dev/ubi0 -s 5888KiB -N efs
ubimkvol /dev/ubi0 -s 40960KiB -N cache
ubimkvol /dev/ubi0 -m -N datadata

# Create LVM partitions
/lvm/sbin/lvm lvremove -f lvpool
/lvm/sbin/lvm pvcreate $MMC_PART
/lvm/sbin/lvm vgcreate lvpool $MMC_PART
format_partitions

/tmp/busybox sync
/tmp/busybox umount /sdcard
/tmp/busybox sleep 10

#/sbin/reboot
exit 0
