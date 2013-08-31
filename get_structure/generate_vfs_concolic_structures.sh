#!/bin/bash -x

output="../staplib/vfslib.stpm"

rm -f "$output"

for i in inode file dentry super_block
do
   ./get_structure.pl --path /home/work/workspace/linux/include/ --name "$i" -m >> "$output"
   echo >> "$output"
done

