#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"

load_default_config || exit 1

lock_script
trap unlock_script EXIT


kdir=''

kernel_version=''
kernel_patchlevel=''
kernel_sublevel=''
kernel_extraversion=''
kversion_str=''

#should set kdir, kernel_* and kverion_str
get_latest_stable_kernel () {
   # link from main page
   local link="http://www.kernel.org/$(wget -q -O - http://www.kernel.org | xmllint --recover --xpath '//*[@id="latest_link"]/a/@href' --html - 2>/dev/null | cut -d '"' -f 2)"
   # kernel archive file name from link
   local kfile="$(echo $link | grep -o -e 'linux-.*$')"
   # kernel source directory after unpacking
   kdir="${ldir}/$(echo $kfile | grep -o -e 'linux-[\.[:digit:]]\+[[:digit:]]')"
   trap "rm -fr '${kdir}'" HUP INT QUIT TERM

   if [[ ! ( -f "$kfile" && -d "$kdir" ) ]]
   then
      wget -Nq $link &&
      tar xf $kfile

      eval $(head -n 4 "${kdir}/Makefile" | tr -d ' ' | tr '[:upper:]' '[:lower:]' | sed -e 's/^/kernel_/' -e 's/[[:blank:]]*$/;/')
      kversion_str="${kernel_version}.${kernel_patchlevel}.${kernel_sublevel}${kernel_extraversion}"

   else
      return 1
   fi
}

get_kernel () {
   local -i ret

   pushd "$ldir"
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

   pushd "$ldir"
      patch_build_makefile &&
      patch_fs_makefiles_for_gcov
      ret=$?
   popd

   return $ret
}

configure_kernel () {
   # latest(by installation time, not by version) available kernel config file;
   local kconfig=$(ls -1 /boot/config-* | sort -nr | head -n 1)
   local -i ret

   pushd "$kdir"
      cp "$kconfig" .config
      #yes '' | make oldconfig > /dev/null
      #make silentoldconfig
      make olddefconfig
      "${ldir}/makeconfig" "${ldir}/makeconfig.conf" "."
      ret=$?
   popd

   return $ret
}

compile_kernel () {
   pushd "$kdir"
      fakeroot make-kpkg --append-to-version '-sprute' --jobs $threads_num --initrd kernel_image kernel_debug kernel_headers
   popd
}

install_kernel () {
   pushd "${kdir}/../"
      if [[ $should_install == 'y' ]]
      then
         if ! check_root_noexit
         then
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

export_buildinfo_from_vm () {
   pushd "$mkimg_shared_folder"
      local cache_dir="./cache/v${kversion_str}/"
      mkdir -p "$cache_dir"
      "${ldir}/mod_merge.sh" "$kdir" "${cache_dir}/depdb" &&
      "${ldir}/merge_sprute.sh" "${cache_dir}/depdb" "$kdir" "${cache_dir}/sprute"
   popd
}

export_deb () {
   pushd "${kdir}/../"
      mkdir -p "${mkimg_shared_folder}/deb/"
      cp -nv *.deb "${mkimg_shared_folder}/deb/"
   popd
}

export_results () {
   export_buildinfo_from_vm
   export_deb
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


gcc_python_plugin_setup &&
get_kernel &&
prepare_kernel &&
configure_kernel &&
compile_kernel &&
export_results &&
install_kernel

