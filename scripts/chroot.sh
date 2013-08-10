#!/bin/bash

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"


chroot_path="$1"
shift

pre_chroot_mount () {
   mount -t proc none "$chroot_path/proc" &&
   mount --rbind /dev "$chroot_path/dev"  &&
   mount -t sysfs sys "$chroot_path/sys"
}

post_chroot_umount () {
   umount "$chroot_path/proc"
   umount "$chroot_path/sys"
   umount --lazy "$chroot_path/dev"
}

exec_cmd () {
   LANG="C.UTF-8" chroot "$chroot_path" /bin/bash -c "$*"
}

run () {
   pre_chroot_mount &&
   trap post_chroot_umount HUP INT QUIT TERM
   exec_cmd "$@"
   post_chroot_umount
}

check_root

run "$@"

