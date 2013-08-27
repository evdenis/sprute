#!/bin/bash

depdb="${1:-depdb}"
kdir="${2:-.}"
outputdir="${3:-sprute}"

if [[ ! -r "$depdb" ]]
then
   echo "Can't find depdb file." 2>&1
fi

if [[ ! ( -d "$kdir" && -e "${kdir}/Kbuild" ) ]]
then
   echo "Path to kernel dir should be provided." 2>&1
fi

mkdir -p "$outputdir"

while read module delim files
do
   sprute_merge=''

   for f in $files
   do
      fname="${kdir}/${f%.o}.c-vfs_ops.sprute"
      if [[ -e "$fname" ]]
      then
         sprute_merge+="$(cat $fname)"
         sprute_merge+=$'\n'
      fi
   done

   if [[ -n "$sprute_merge" ]]
   then
      echo "$sprute_merge" > "${outputdir}/$(basename ${module%.ko}).sprute"
   fi
done < "$depdb"

