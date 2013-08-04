#!/bin/bash

# $1 - kernel sources directory
# $2 - subdirectory for makefiles patch

patch_makefiles () {
	local patchstr="GCOV_PROFILE := y"

	for i in $(find . -type f -name Makefile)
	do
		grep -qFe "$patchstr" "$i" || { sed -i -e "1i $patchstr" "$i" > /dev/null 2>&1 && echo "SUCCESS: $i" || echo "FAIL: $i"; }
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
	patch_makefiles
popd

