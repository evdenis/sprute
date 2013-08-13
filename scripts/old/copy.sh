#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"

load_default_config || exit 1

copy_sprute () {
   mkdir -p "$sprute_dir"
   pushd "${ldir}/../"
      # --exclude='scripts/' doesn't work  
      rsync -vRau $(git ls-tree -r HEAD --name-only . | grep -vFe 'scripts/') "$sprute_dir"
   popd
}

copy_scripts () {
   mkdir -p "$scripts_dir"
   pushd "$ldir"
      rsync -vRau $(git ls-tree -r HEAD --name-only .) "./data/vm_img.conf" "$scripts_dir"
   popd
}

copy_files () {
	copy_scripts &&
	copy_sprute
}

check_root

copy_files

