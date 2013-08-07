#!/bin/bash -x

user="work"
name="test.raw"
size="20G"
system="./debian32/"
mountpoint="/mnt/s2e_test_img/"
mbr="/usr/share/syslinux/mbr.bin"

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"


# we can use partx to notify kernel about new partition on loop device

# $1 - img name
# $2 - img size
create_raw_img () {
   truncate -s "$2" "$1"
   chown "${user}:${user}" "$1"
}

# TODO: param to spec filsystem on currently hidden part
# $1 - img name
partition_img () {
   check_file "$1" &&
   parted "$1" -s -- mklabel msdos &&
   parted "$1" -s -- mkpart primary ext2 1MiB 10GiB set 1 boot on &&
   parted "$1" -s -- mkpart primary linux-swap 10GiB 12GiB &&
   parted "$1" -s -- mkpart primary 12GiB -1 set 3 hidden on
}


loopdev=''
# $1 - img name
# $2 - mountpoint
mount_img () {
   if ! check_file "$1"
   then
      return 1
   fi

   mkdir -p "$2"
   loopdev=$(losetup -P --find --show "$1") &&
   mkfs.ext2 "${loopdev}p1" &&
   mkswap "${loopdev}p2" &&
   mount "${loopdev}p1" "$2"
}

# $1 - orig
# $2 - dest
copy_root () {
   check_dir "$1" &&
   check_dir "$2" &&

   rsync -rpa "${1}/" "$2"
}

# $1 - device
# $2 - mountpoint
# $3 - mbr file
install_extlinux () {
   if [[ -e "$1" ]] && check_dir "$2" && check_file "$3"
   then
      #local -i size=$(stat -c '%s' "$3") &&
      #extlinux --install "${2}/boot/" &&
      #dd bs=$size conv=notrunc count=1 if="$3" of="$1" &&

      "${ldir}/chroot.sh" "$2" extlinux-install "$1" \&\& extlinux-update
   else
      return 1
   fi
}

# $1 - mountpoint
update_fstab () {
   if check_dir "$1"
   then
      local fstab="${1}/etc/fstab"
      grep -qFe '/dev/sda1' "$fstab" || { echo '/dev/sda1 / ext2 defaults 1 1'>> "$fstab";}
      grep -qFe '/dev/sda2' "$fstab" || { echo '/dev/sda2 swap swap defaults 0 0'>> "$fstab";}
   else
      return 1
   fi
}

# $1 - mountpoint
setup_root_autologin () {
   check_dir "$1" &&
   sed -i -e 's#1:2345:respawn:/sbin/getty 38400 tty1#& --autologin root#' "${1}/etc/inittab"
}

# $1 - bootstrap 
# $2 - mountpoint
# $3 - mbr file
deploy_system () {
   check_dir "$1" &&
   check_dir "$2" &&
   check_file "$3" &&

   copy_root "$1" "$2" &&
   update_fstab "$2" &&
   setup_root_autologin "$2" &&
   install_extlinux "$loopdev" "$2" "$3"
}

umount_img () {
   umount "${loopdev}p1"
   losetup -d "$loopdev"
}

check_root

create_raw_img "$name" "$size" &&
partition_img  "$name" &&
mount_img "$name" "$mountpoint" &&
trap "umount_img" HUP INT QUIT TERM &&
deploy_system "$system" "$mountpoint" "$mbr"
umount_img

