#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"

load_default_config || exit 1

packets=(systemtap systemtap-client systemtap-server)
packets+=(extlinux linux-image-686-pae)
packets+=(kernel-package fakeroot libncurses5-dev)
packets+=(expect git libxml2-utils cron ssh liblockfile-bin bc)
packets+=(wget ca-certificates)
#gcc-python-plugin deps python-devel
#packets+=(gcc-4.8-plugin-dev) script should install apropriate version of package
packets+=(python-dev python-six python-pygments python-sphinx graphviz)
packets+=(dosfstools jfsutils xfsprogs reiserfsprogs)
packets+=(bonnie++)


deploy_debian () {
   local -i ret

   IFS=','
   mkdir -p "$dir"
#   debootstrap --arch=i386 --include="${packets[*]}"  --variant=buildd sid "$dir"
   debootstrap --arch=i386 --include="${packets[*]}" sid "$dir"
   ret=$?
   unset IFS
   return $ret
}


check_root

deploy_debian
