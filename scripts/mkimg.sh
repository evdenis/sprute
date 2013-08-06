#!/bin/bash -x

name="test.raw"
size="20G"
system="./debian32/"
mountpoint="/mnt/s2e_test_img/"

# we can use partx to notify kernel about new partition on loop device

# $1 - img name
# $2 - img size
create_raw_img () {
   truncate -s "$2" "$1"
}

# TODO: param to spec filsystem on currently hidden part
# $1 - img name
partition_img () {
   parted "$1" -s -- mklabel msdos &&
   parted "$1" -s -- mkpart primary ext2 1MiB 10GiB set 1 boot on &&
   parted "$1" -s -- mkpart primary linux-swap 10GiB 12GiB &&
   parted "$1" -s -- mkpart primary 12GiB -1 set 3 hidden on
}


loopdev=''
# $1 - img name
# $2 - mountpoint
mount_img () {
   mkdir -p "$2"
   loopdev=$(losetup -P --find --show "$1") &&
   mkfs.ext2 "${loopdev}p1" &&
   mount "${loopdev}p1" "$2"
}

copy_root () {
   rsync -rpa "${system}/" "$mountpoint"
}

install_grub () {
#   grub2-install --boot-directory="${mountpoint}/boot/" --modules="ext2 part_msdos" "$loopdev"
http://superuser.com/questions/130955/how-to-install-grub-into-an-img-file


modprobe dm_mod
kpartx -va /root/rootfs.img # *.img is setup elsewhere
# normally you now would mount /dev/loop0p1 directly. BUT
# grub specialists didn't manage to work with loop partitions other than /dev/loop[0-9]
losetup -v -f --show /dev/mapper/loop0p1
mount /dev/loop1 /mnt
mkdir -p /mnt/boot/grub

# change into chrooted environment. all remaining work will be done from here. this differs from the howto above.
LANG=C chroot /mnt /bin/bash
set -o vi
mount -t sysfs sysfs /sys
mount -t proc  proc  /proc
# avoid grub asking questions
cat << ! | debconf-set-selections -v
grub2   grub2/linux_cmdline                select   
grub2   grub2/linux_cmdline_default        select   
grub-pc grub-pc/install_devices_empty      select yes
grub-pc grub-pc/install_devices            select   
!
apt-get -y install grub-pc
# don't setup device.map prior to this point. It will be overwritten by grub-pc install
cat > /mnt/boot/grub/device.map << !
(hd0)   /dev/loop0
(hd0,1) /dev/loop1
!
# install here to fill /boot/grub for grub-mkconfig (update-grub)
grub-install /dev/loop0
# generate /boot/grub/grub.cfg
update-grub

}

# $1 - mountpoint
update_fstab () {
   local fstab="${1}/etc/fstab"
   grep -qFe '/dev/sda1' "$fstab" || { echo '/dev/sda1 / ext2 defaults 1 1'>> "$fstab";}
   grep -qFe '/dev/sda2' "$fstab" || { echo '/dev/sda2 swap swap defaults 0 0'>> "$fstab";}
}

deploy_system () {
   copy_root &&
   update_fstab &&
   install_grub
}

umount_img () {
   umount "${loopdev}p1"
   losetup -d "$loopdev"
}

#check_root

create_raw_img "$name" "$size" &&
partition_img  "$name" &&
mount_img "$name" "$mountpoint" &&
trap "unmount_img" HUP INT QUIT TERM &&
deploy_system "$mountpoint"
umount_img


#losetup -D
