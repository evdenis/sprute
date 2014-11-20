#!/usr/bin/env bash

dir=/home/work/workspace/linux/include/

./get_structure.pl --path $dir --name super_operations --extract_operations | sed -e 's/^/ops_super_/' -
echo
./get_structure.pl --path $dir --name inode_operations --extract_operations | sed -e 's/^/ops_inode_/' -
echo
./get_structure.pl --path $dir --name dentry_operations --extract_operations | sed -e 's/^d_/ops_dentry_/' -
echo
./get_structure.pl --path $dir --name file_operations --extract_operations | sed -e 's/^/ops_file_/' -


