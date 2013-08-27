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
   {
      if [[ "$vm_type" == 'work' ]]
      then
         parted "$1" -s -- mkpart primary ext2 1MiB -1GiB set 1 boot on &&
         parted "$1" -s -- mkpart primary linux-swap -1GiB -1MiB
      elif [[ "$vm_type" == 'test' ]]
      then
         parted "$1" -s -- mkpart primary ext2 1MiB 20GiB set 1 boot on &&
         parted "$1" -s -- mkpart primary linux-swap 20GiB 21GiB &&
         parted "$1" -s -- mkpart primary 21GiB -1MiB set 3 hidden on
      fi
   }
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

# $1 - root dir
generate_extlinux_config () {
   if ! check_dir "$1"
   then
      return 1
   fi
   local -i number=0
   local version=''
   local config="
default l0
timeout 3

"

   for i in $(get_kernels_list "${1}/boot")
   do
      version="$(echo "$i" | sed -e 's/vmlinuz-//g')"

	   if [[ -e "${1}/boot/initrd.img-${version}" ]]
   	then
	   	initrd="initrd=/boot/initrd.img-${version}"
   	else
	   	initrd=""
   	fi

	   # Writing default entry
   	config="${config}

label l${number}
	menu label Debian GNU/Linux, kernel ${version}
	linux /boot/vmlinuz-${version}
	append ${initrd} root=/dev/sda1 ro"

   	number="$((${number} + 1))"
   done
   echo "${config}"
}

# $1 - device
# $2 - mountpoint
install_extlinux () {
   local mbrfile='/usr/share/syslinux/mbr.bin'

   [[ -e "$1" ]] && check_dir "$2" &&
   {
      local -i size=$(stat -c '%s' "$mbrfile") &&
      dd bs=$size conv=notrunc count=1 if="$mbrfile" of="$1" &&
      mkdir -p "${2}/boot/extlinux" &&
      extlinux --install "${2}/boot/extlinux" &&
      generate_extlinux_config "$2" > "${2}/boot/extlinux/extlinux.conf"
   }

   #"${ldir}/chroot.sh" "$2" extlinux-install "$1" \&\& extlinux-update
}

# $1 - mountpoint
update_fstab () {
   if check_dir "$1"
   then
      local fstab="${1}/etc/fstab"
      grep -qFe '/dev/sda1' "$fstab" || { echo '/dev/sda1 / ext2 defaults 1 1' >> "$fstab"; }
      grep -qFe '/dev/sda2' "$fstab" || { echo '/dev/sda2 swap swap defaults 0 0' >> "$fstab"; }
      if [[ -n "$shared_folder_tag" ]]
      then
         grep -qFe "$shared_folder_tag" "$fstab" || {
            mkdir -p "${1}/${shared_folder}/";
            echo "${shared_folder_tag} ${shared_folder} 9p trans=virtio,noauto 0 0" >> "$fstab";
         }
      fi
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

# $1 - mountpoint
setup_network () {
   check_dir "$1" &&
cat > "${1}/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
   if [[ -n $shared_folder_tag ]]
   then
      echo "post-up mount ${shared_folder_tag}" >> "${1}/etc/network/interfaces"
   fi
}

# $1 - mountpoint
# $2 - scripts dir
setup_cron () {
   if check_dir "${1}/${2}"
   then
      local crontab="${1}/etc/crontab"

      grep -qFe "kernel.sh"    "$crontab" || { echo "0 * * * * root ${2}/kernel.sh" >> "$crontab"; }
      #grep -qFe "gccpython.sh" "$crontab" || { echo "0 0 */7 * * root ${2}/gccpython.sh" >> "$crontab"; }
   else
      return 1
   fi
}


# $1 - bootstrap 
# $2 - mountpoint
deploy_system () {
   check_dir "$1" &&
   check_dir "$2" &&

   copy_root "$1" "$2" &&
   update_fstab "$2"   &&
   setup_network "$2"
}

umount_img () {
   sync
   umount "${loopdev}p1"
   sleep 3s
   sync
   losetup -d "$loopdev"
}

# $1 - system
update_bootstrap () {
   if [[ $should_upgrade_bootstrap == 'y' ]]
   then
      check_dir "$1" &&
      # Use carefully because of Fedora bug.
      "${ldir}/chroot.sh" "$1" apt-get update \&\& apt-get --assume-yes --force-yes upgrade \&\& apt-get clean
   fi
}

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

         mkdir -p --mode=700 "${user_home}/.ssh/" &&
         cp -fv "$3" "${user_home}/.ssh/id_rsa" &&
         cp -fv "${3}.pub" "${user_home}/.ssh/id_rsa.pub" &&
         if check_file "$4"; then cat "$4" >> "${user_home}/.ssh/authorized_keys"; fi  &&
         chown -R ${user_id}:${user_id} "${user_home}/.ssh/"
      }
   fi
}

copy_sprute () {
   local -i ret
   mkdir -p "${mountpoint}/${vm_sprute_dir}"
   pushd "${ldir}/../"
      # --exclude='scripts/' doesn't work
      rsync -vRau $(git ls-tree -r HEAD --name-only . | grep -vFe 'scripts/') "${mountpoint}/${vm_sprute_dir}"
      ret=$?
   popd
   return $ret
}

copy_scripts () {
   local -i ret
   mkdir -p "${mountpoint}/${vm_scripts_dir}"
   pushd "$ldir"
      rsync -vRau $(git ls-tree -r HEAD --name-only .) "./data/vm_img.conf" "${mountpoint}/${vm_scripts_dir}"
      ret=$?
   popd
   return $ret
}

#FIXME: dirty hack
#copy_scripts_sharedfolder_host () {
#   local -i ret
#   mkdir -p "${run_shared_host_shared_folder}"
#   pushd "$ldir"
#      rsync -vRau $(git ls-tree -r HEAD --name-only .) "./data/vm_img.conf" "${run_shared_host_shared_folder}"
#      ret=$?
#   popd
#   return $ret
#}


install_sprute () {
   if [[ $copy_sprute_sources == 'y' ]]
   then
      if [[ "$vm_type" == 'work' ]]
      then
#        copy_scripts_sharedfolder_host
         copy_scripts
         mkdir -p "${mountpoint}/${shared_folder}/"
      fi
      copy_sprute
   fi
   if [[ $install_sprute_binaries == 'y' ]] && check_dir "$sprute_binaries_dir"
   then
      #TODO: implement
      true
   fi
}

install_kernel () {
   if [[ -n "$kernel_install" ]] && check_dir "$kernel_packet_dir"
   then
		mkdir -p "$mountpoint/tmp/packets"
		cp -fv "${kernel_packet_dir}/"*"$kernel_install"*.deb "${mountpoint}/tmp/packets"
      #Normally we should use chroot.sh but it will lead to problems with PTY opening and loop unmounting. Fedora bug.
		chroot "$mountpoint" bash -c "cd /tmp/packets/; dpkg -i *.deb"
		rm -fr "$mountpoint/tmp/packets"
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
install_ssh_keys "$mountpoint" root "$vm_ssh_key" "$host_ssh_pub_key" &&
install_sprute &&
{ if [[ "$vm_type" == 'work' ]]; then setup_cron "$mountpoint" "$vm_scripts_dir"; fi; } &&
install_kernel &&
install_extlinux "$loopdev" "$mountpoint"

#if [[ $vm_type == 'test' ]]
#then
#   setup_shared_folder
#   setup_inotify
#   modify_bashrs
#fi

umount_img

