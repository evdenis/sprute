#!/bin/bash

val=1

echo ${0%.sh}

name=$(basename $0)
name=${name%.sh}

#conf_path="${ldir}/data/vm_img.conf.example"
conf_path="./vm_img.conf.example"

check_file ()
{
   true
}

load_config () {
   if check_file "$conf_path"
   then
      local list=$(grep -o -e "^${name}_[^=]*" "$conf_path" | uniq)
      local line=''

#      while read -s line
#      do
#         for i in 
#      done
      local regexp=''
      for i in $list
      do
         regexp+=" $i ${i#${name}_}"
      done

      replace $regexp -- < $conf_path
#     eval $(sed -e "s/^${name}_//" )

   else
      return 1
   fi
}


load_config
#echo $mkimg_user
#echo $val


