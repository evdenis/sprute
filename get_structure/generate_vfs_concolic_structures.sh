#!/bin/bash -x

[[ -z "$1" ]] && exit 1

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

kdir="$1"
cbdir="${2:-${kdir}/sprute/}"
depdb="${3:-${kdir}/depdb}"

output="${ldir}/../staplib/vfslib.stpm"

rm -f "$output"

for i in inode file dentry super_block
do
   "${ldir}/get_structure.pl" --path "${kdir}/include/" --name "$i" -m >> "$output"
   echo >> "$output"
done

output="${ldir}/../staplib/"

for i in inode file dentry super
do
	"${ldir}/get_structure.pl" --path "${kdir}/include/" --name "${i}_operations" -e > "${output}/vfslib_${i}.stpm"
done

for i in fat msdos vfat minix jfs
do
   "${ldir}/gen_rules.pl" --path "$kdir" --cbdir "$cbdir" --depdb "$depdb" --module "$i" > "${ldir}/../${i}.stp"
done

