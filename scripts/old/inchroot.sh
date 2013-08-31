#!/bin/bash

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"


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

setup_root_autologin () {
   sed -i -e 's#1:2345:respawn:/sbin/getty 38400 tty1#& --autologin root#' /etc/inittab
}

check_root

setup_root_autologin

"${ldir}/setup_cron.sh"

