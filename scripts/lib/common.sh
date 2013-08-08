
declare -i processors_num=$(grep -e '^processor' < /proc/cpuinfo | wc -l)
declare -i threads_num=$(( $processors_num * ${PR_COEFF:-1} ))
[[ $threads_num -eq 0 ]] && threads_num=1


if [[ -d "$ldir" ]]
then
	#dir of calling script
	#note the difference between $0 and ${BASH_SOURCE[0]}
	ldir="$( cd "$( dirname "$0" )" && pwd )"
fi


lock () {
   dotlockfile -l -r 0 -p "$1"
}

unlock () {
   dotlockfile -u "$1"
}


lockname="${ldir}/${0}.lock"

lock_script () {
	lock "$lockname" || exit 0
}

unlock_script () {
	unlock "$lockname"
}


check_root () {
   if [[ $EUID -ne 0 ]]
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

      eval $(replace $regexp -- < $1)
   else
      return 1
   fi
}

load_default_config () {
   local default_conf_path="${ldir}/data/vm_img.conf"
   load_config "$default_conf_path"
}

