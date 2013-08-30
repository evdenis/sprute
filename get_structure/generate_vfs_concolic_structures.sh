#!/bin/bash -x

rm -f vfslib.stp

for i in inode file dentry super_block
do
   ./get_structure.pl --path /home/work/workspace/linux/include/ --name "$i" -m >> vfslib.stp
   echo >> vfslib.stp
done

