#!/bin/bash

cd /usr/src/linux/fs/

#sed -i '1i GCOV_PROFILE := y\n' "$(find . -type f -name Makefile)"
for i in $(find . -type f -name Makefile)
do
	sed -i '/GCOV_PROFILE := y/d' "$i"
done

