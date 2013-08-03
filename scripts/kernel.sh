#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

declare -i processors_num=$(grep -e '^processor' < /proc/cpuinfo | wc -l)
declare -i threads_num=$(( $processors_num * ${PR_COEFF:-1} ))
[[ $threads_num -eq 0 ]] && threads_num=1

kdir=''

#should set kdir
get_latest_stable_kernel () {
	# link from main page
	local link="http://www.kernel.org/$(wget -q -O - http://www.kernel.org | xmllint --recover --xpath '//*[@id="latest_link"]/a/@href' --html - 2>/dev/null | cut -d '"' -f 2)"
   # kernel archive file name from link
   local kfile="$(echo $link | grep -o -e 'linux-.*$')"
   # kernel source directory after unpacking
   kdir="$(echo $kfile | grep -o -e 'linux-[\.[:digit:]]\+[[:digit:]]')"

	if [[ ! ( -f $kfile && -d $kdir ) ]]
	then
	   wget -q $link &&
   	tar xf $kfile
	else
		return 1
	fi	
}

get_kernel () {
	local -i ret
   pushd $ldir
		get_latest_stable_kernel
		ret=$?
   popd
	return $ret
}

prepare_kernel () {
	local -i ret
   pushd $ldir
		#patch 
		#ret=$?
		#TODO: implement
		ret=0
   popd
	return $ret

}

configure_kernel () {
	# latest(by installation time, not by version) available kernel config file;
   # FIXME: by version
  	local KCONFIG=$(ls -1 -t /boot/config-* | head -n 1)
	local -i ret

	pushd $kdir
   	cp $KCONFIG .config
	   #yes '' | make oldconfig > /dev/null
   	#make olddefconfig
	   make silentoldconfig
		$ldir/makeconfig.exp
		ret=$?
	popd

	return $ret
}

compile_kernel () {
	pushd $kdir
		fakeroot make-kpkg --append-to-version sprute --jobs $threads_num --initrd kernel_image kernel_debug kernel_headers
	popd
}

get_kernel &&
prepare_kernel &&
configure_kernel &&
compile_kernel

