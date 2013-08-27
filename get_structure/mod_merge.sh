#!/bin/bash

kdir="${1:-.}"
output="${2:-depdb}"

rm -f "$output"

if [[ -d "${kdir}/.tmp_versions" ]]
then
   awk 'FNR==1{ printf "%s := ", $0 } FNR==2{ print $0 }' "${kdir}/.tmp_versions/"*.mod >> "$output"
else
   echo "Can't find .tmp_versions dir." 1>&2
   exit 1
fi

