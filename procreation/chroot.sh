#!/bin/bash

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"

load_default_config || exit 1

path="$1"
shift

loop_mount=''

if [[ -d "$path" ]]
then
   chroot_path="$path"
   loop_mount='n'
elif [[ -f "$path" ]]
then
   loop_mount='y'
else
   echo "Path to chroot folder or raw image should be provided." 1>&2
   exit 1
fi

loopdev=''

pre_chroot_mount () {
   if [[ "$loop_mount" == 'y' ]]
   then
      chroot_path="${default_dir:-$(mktemp -d)}" &&
      mkdir -p $chroot_path &&
      loopdev=$(losetup -P --find --show "$path") &&
      mount "${loopdev}p1" "$chroot_path" || return 1
   fi
   mount -t proc none "$chroot_path/proc" &&
   mount --rbind /dev "$chroot_path/dev"  &&
   mount -t sysfs sys "$chroot_path/sys"
}

post_chroot_umount () {
   umount "$chroot_path/proc"
   umount "$chroot_path/sys"
   umount --lazy "$chroot_path/dev"
   if [[ "$loop_mount" == 'y' ]]
   then
      sync
      umount "${loopdev}p1" &&
      sleep 3s &&
      losetup -d "$loopdev" &&
      rmdir "$chroot_path"
   fi
}

exec_cmd () {
   LANG="C.UTF-8" chroot "$chroot_path" /bin/bash -c "$*"
}

run () {
   pre_chroot_mount &&
   trap post_chroot_umount HUP INT QUIT TERM &&
   exec_cmd "$@"
   post_chroot_umount
}

check_root

run "$@"

