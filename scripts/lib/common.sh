
declare -i processors_num=$(grep -e '^processor' < /proc/cpuinfo | wc -l)
declare -i threads_num=$(( $processors_num * ${PR_COEFF:-1} ))
[[ $threads_num -eq 0 ]] && threads_num=1


if [[ ! -d "$ldir" ]]
then
   #dir of calling script
   #note the difference between $0 and ${BASH_SOURCE[0]}
   ldir="$( cd "$( dirname "$0" )" && pwd )/../"
fi


lock () {
   dotlockfile -l -r 0 -p "$1"
}

unlock () {
   dotlockfile -u "$1"
}


lockname="${ldir}/$(basename ${0}).lock"

lock_script () {
   lock "$lockname" || exit 0
}

unlock_script () {
   unlock "$lockname"
}


check_root_noexit () {
   [[ $EUID -ne 0 ]]
}

check_root () {
   if check_root_noexit
   then
      echo "This script must be run as root" 1>&2
      exit 1
   fi
}

check_file () {
   [[ -f "$1" ]]
}

check_dir () {
   [[ -d "$1" ]]
}

load_config () {
   if check_file "$1"
   then
      local scriptname="$(basename $0)"
      scriptname="${scriptname%.sh}"
      local list=$(grep -o -e "^${scriptname}_[^=]*" "$1" | uniq)
      local line=''
      local regexp=''

      for i in $list
      do
         regexp+=" $i ${i#${scriptname}_}"
      done

      # We should not use replace
      source <(sed -e "$(echo $regexp | sed -e 's/\([[:alnum:]_]\+\)[[:blank:]]\+\([[:alnum:]_]\+\)/s%\1%\2%g;/g')" "$1")
#      source <(replace $regexp -- < "$1")
   else
      return 1
   fi
}

load_default_config () {
   local default_conf_path="${ldir}/data/vm_img.conf"
   load_config "$default_conf_path"
}

# function may be called only with root privilegies
in_chroot () {
   [[ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]]
}

# $1 - dir
get_kernels_list () {
   check_dir "$1" &&
   {
      pushd "$1" > /dev/null 2>&1
      ls -1 vmlinuz-* | grep -v .dpkg-tmp | sort -nr
      popd > /dev/null 2>&1
   }
}

# $1 - dir
find_latest_kernel () {
   get_kernels_list "$1" | head -n 1
}

