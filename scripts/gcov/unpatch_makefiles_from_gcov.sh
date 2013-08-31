#!/bin/bash

# $1 - kernel sources directory
# $2 - subdirectory for makefiles patch

unpatch_makefiles () {
   local patchstr="GCOV_PROFILE := y"

   #sed -i '1i GCOV_PROFILE := y\n' "$(find . -type f -name Makefile)"
   for i in $(find . -type f -name Makefile)
   do
      sed -i -e "/${patchstr}/d" "$i"
   done
}

#FIXME: add to lib
#check_kernel_sources_dir
if [[ ! ( -d "$1" && -e "$1/Kbuild" ) ]]
then
   echo "Not in the kernel sources directory." 2>&1
   exit 1
fi

if [[ -d "$2" ]]
then
   echo "Subdirectory should be set." 2>&1
   exit 1
fi

pushd "${1}/${2}"
   unpatch_makefiles
popd

