#!/bin/bash

cd /usr/src/linux/fs/

PATCHSTR="GCOV_PROFILE := y"

for i in $(find . -type f -name Makefile)
do
	grep -qFe "$PATCHSTR" "$i" || { sed -i "1i $PATCHSTR" "$i" > /dev/null 2>&1 && echo "SUCCESS: $i" || echo "FAIL: $i"; }
done
