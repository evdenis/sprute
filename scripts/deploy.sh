#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"


dir=debian32
scriptsd="${dir}/root/"

packets=(systemtap systemtap-client systemtap-server)
packets+=(grub-pc linux-image-686-pae)
packets+=(kernel-package fakeroot ncurses-dev)
packets+=(expect git libxml2-utils cron)
packets+=(wget ca-certificates)
#gcc-python-plugin deps python-devel 
#packets+=(gcc-4.8-plugin-dev) script should install apropriate version of package
packets+=(python-dev python-six python-pygments python-sphinx graphviz)



deploy_debian () {
	local -i ret

	IFS=','
	mkdir -p "$dir"
	debootstrap --arch=i386 --include="${packets[*]}"  --variant=buildd sid "$dir"
	ret=$?
	unset IFS
	return $ret
}

copy_sprute () {
	true
}

copy_scripts () {
	cp -fr "$ldir" "$scriptsd"
}

copy_files () {
	copy_scripts &&
	copy_sprute
}

check_root

deploy_debian &&
copy_files "$dir" &&
./chroot.sh "$dir" "${scriptsd}/inchroot.sh"

