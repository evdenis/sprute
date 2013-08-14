#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"

lock_script

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
	   wget -Nq $link &&
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

patch_build_makefile () {
	local -i ret
   local patchfile="${ldir}/data/linux-makefile.patch"

   sed -e "s:%PATH%:${mkimg_vm_sprute_dir}/gccplugin/:" "$patchfile" | patch -p1 -d "$kdir"
	ret=$?

	if [[ $ret -ne 0 ]]
	then
		echo "WARNING: Can't apply makefile patch for your kernel."
	fi

	return $ret
}

patch_fs_makefiles_for_gcov () {
   "${ldir}/gcov/patch_makefiles_for_gcov.sh" "$kdir" "fs"
}

prepare_kernel () {
	local -i ret

   pushd $ldir
      patch_build_makefile &&
      patch_fs_makefiles_for_gcov 
		ret=$?
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
	   #make silentoldconfig
   	make olddefconfig
		$ldir/makeconfig.exp
		ret=$?
	popd

	return $ret
}

compile_kernel () {
	pushd $kdir
		fakeroot make-kpkg --append-to-version '-sprute' --jobs $threads_num --initrd kernel_image kernel_debug kernel_headers
	popd
}

install_kernel () {
   pushd $HOME
      if [[ $should_install == 'y' ]]
      then
         if check_root_noexit
         then
            eval $(head -n 4 "${kdir}/Makefile" | tr -d ' ' | tr '[:upper:]' '[:lower:]' | sed -e 's/^/local kernel_/' -e 's/[[:blank:]]*$/;/')
            local kversion_str="${kernel_version}.${kernel_patchlevel}.${kernel_sublevel}${kernel_extraversion}"

            dpkg -i linux-{headers,image}-"${kversion_str}"*.Custom_i386.deb
            if ! in_chroot
            then
               reboot
            fi
         else
            echo "Can't install kernel without root privileges."
         fi
      fi
   popd
}

check_command () {
   command -v "$1" > /dev/null 2>&1
}

gcc_python_plugin_setup () {
   if ! check_command "gcc-with-python"
   then
     "${ldir}/gccpython.sh"
   fi
}


trap "unlock_script; rm -fr '${kdir}'" HUP INT QUIT TERM

gcc_python_plugin_setup &&
get_kernel &&
prepare_kernel &&
configure_kernel &&
compile_kernel &&
install_kernel

unlock_script

