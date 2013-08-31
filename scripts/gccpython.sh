#!/bin/bash -x

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"


lock_script
trap unlock_script EXIT

pdir=''

check_git_dir () {
   ! [[ -d $1 && -d "$1/.git" ]]
}

get_gccpython () {
   pdir="${ldir}/gcc-python-plugin"
   local -i ret

   pushd $ldir
      if check_git_dir "$pdir"
      then
         git clone git://git.fedorahosted.org/gcc-python-plugin.git
         ret=$?
         trap "rm -fr '${pdir}'" HUP INT QUIT TERM
      else
         cd $pdir
         local out="$(git pull)"
         if [[ $? -eq 0 && "$out" == 'Already up-to-date.' ]]
         then
            ret=1
         else
            ret=0
         fi
      fi
   popd

   return $ret
}

compile_gccpython () {
   local -i ret

   pushd $pdir
      make -j $threads_num plugin
      ret=$?
   popd

   return $ret
}

install_gccpython () {
   pushd $pdir
      make install
   popd
}

install_gcc_plugin_dev () {
   local gcc_version="$(gcc --version | head -n 1 | rev | cut -d ' ' -f 1 | rev | cut -d '.' -f 1-2)"
   local gcc_pldev_packet="gcc-${gcc_version}-plugin-dev"
   local status="$(dpkg-query -W -f='${Status}' ${gcc_pldev_packet})"

   if [[ "$status" != 'install ok installed' ]]
   then
      apt-get -f install --assume-yes --force-yes $gcc_pldev_packet
      return $?
   fi

   return 0
}


check_root

install_gcc_plugin_dev &&
get_gccpython     &&
compile_gccpython &&
install_gccpython

