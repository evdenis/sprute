#!/bin/bash

source ./sprute.conf

stub () {
   echo 'UNIMPLEMENTED YET'
}

pre_chroot_mount () {
   mount -t proc none "$CHROOT_PATH/proc" &&
   mount --rbind /dev "$CHROOT_PATH/dev"  &&
   mount -t sysfs sys "$CHROOT_PATH/sys" 
}

post_chroot_umount () {
   umount "$CHROOT_PATH/proc"
   umount "$CHROOT_PATH/sys"
   umount --lazy "$CHROOT_PATH/dev"
}


debian_chroot_stap_compilation () {
   LANG="C.UTF-8" chroot $CHROOT_PATH /bin/bash
#   LANG="C.UTF-8" chroot "$CHROOT_HOME/sprute" /bin/bash ./compile.sh
}

setup_compilation_env () {
   mkdir -p "$CHROOT_HOME/bin/"
   #upload fakeuname
   cp -f "$FAKEUNAME" "$CHROOT_HOME/bin/" &&
   #upload_sprute
   rsync -ur --exclude '/.git' "$SPRUTE_SRC_DIR" "$CHROOT_HOME/sprute"
}

get_stap_binaries () {
   stub
   #cp
   #chown work:work -r
}

run () {
   setup_compilation_env &&

   pre_chroot_mount &&
   debian_chroot_stap_compilation &&
   get_stap_binaries
   post_chroot_umount
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

run

