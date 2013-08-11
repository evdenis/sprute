#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"

vm_type='test'

if [[ -n "$1" ]]
then
   case "$1" in
      t|test)
         vm_type='test';;
      w|work)
         vm_type='work';;
      *)
         echo "Unknown type: ${1}" 2>&1;
         exit 1;;
   esac
fi

load_default_config || exit 1


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
install_extlinux () {
   [[ -e "$1" ]] && check_dir "$2" &&

   "${ldir}/chroot.sh" "$2" extlinux-install "$1" \&\& extlinux-update
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
# $2 - user
check_user_chroot () {
   check_dir "$1" &&
   grep -qe "^${2}" "${1}/etc/passwd"
}

# $1 - mountpoint
# $2 - user
setup_autologin () {
   check_dir "$1" &&
   #"${ldir}/chroot.sh" id -u "$2" &&
   check_user_chroot "$1" "$2" &&
   sed -i -e "s#1:2345:respawn:/sbin/getty 38400 tty1#& --autologin ${2}#" "${1}/etc/inittab"
}

# $1 - bootstrap 
# $2 - mountpoint
deploy_system () {
   check_dir "$1" &&
   check_dir "$2" &&

   copy_root "$1" "$2" &&
   update_fstab "$2" &&
   install_extlinux "$loopdev" "$2"
}

umount_img () {
   umount "${loopdev}p1"
   losetup -d "$loopdev"
}

# $1 - system
update_bootstrap () {
   if [[ $should_upgrade_bootstrap == 'y' ]]
   then
      check_dir "$1" &&
      "${ldir}/chroot.sh" "$1" apt-get update \&\& apt-get --assume-yes --force-yes upgrade \&\& apt-get clean
   fi
}

#FIXME: doesn't work yet. Don't know why.
# $1 - mountpoint
# $2 - user
# $3 - path to keys for vm
# $4 - path to host pub key
install_ssh_keys () {
   #TODO: maybe pub key is unnecessary
   if check_file "$3" && check_file "${3}.pub"
   then
      check_dir "$1" &&
      check_user_chroot "$1" "$2" &&
      {
         local user_home="$1"
         if [[ "$2" == 'root' ]]
         then
            user_home+='/root/'
         else
            user_home+="/home/${2}"
         fi

         local -i user_id=$(grep -e "^${2}" "${1}/etc/group" | cut -d ':' -f 3) &&

         mkdir --mode=700 "${user_home}/.ssh/" &&
         cp -fv "$3" "${3}.pub" "${user_home}/.ssh/" &&
         if check_file "$4"; then cat "$4" >> "${user_home}/.ssh/authorized_keys"; fi  &&
         chown -R ${user_id}:${user_id} "${user_home}/.ssh/"
      }
   fi
}

install_sprute () {
   if [[ $copy_sprute_sources == 'y' ]]
   then
      "${ldir}/copy.sh"
   fi
   if [[ $install_sprute_binaries == 'y' ]] && check_dir "$sprute_binaries_dir"
   then
      #TODO: implement
      true
   fi
}

install_kernel () {
   if [[ -n "$kernel_install" ]] && check_dir "$kernel_dir" 
   then
      #TODO: implement
      true
   fi
}

check_root

update_bootstrap "$system"

create_raw_img "$name" "$size" &&
partition_img  "$name" &&
mount_img "$name" "$mountpoint" &&
trap "umount_img" HUP INT QUIT TERM &&
deploy_system "$system" "$mountpoint" &&
setup_autologin "$mountpoint" root &&
install_ssh_keys "$mountpoint" root "$vm_ssh_key" "$host_ssh_pub_key"
install_sprute &&
install_kernel

umount_img

