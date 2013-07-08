#!/bin/bash -e

DEST=$1
FS=$2
DEBUG=/sys/kernel/debug/gcov/usr/src/linux/fs
GCDA="${DEBUG}/${FS}"

#if [ -d "$DEST" ] ; then
#   echo "Usage: $0 <output.tar.gz>" >&2
#   exit 1
#fi

#TEMPDIR=$(mktemp -d)

echo Collecting data..
#find $GCDA -type d -exec mkdir -p $DEST/\{\} \;
#find $GCDA -name '*.gcda' -exec sh -c 'cat < $0 > '$DEST'/$0' {} \;
#find $GCDA -name '*.gcno' -exec sh -c 'cp -d $0 '$DEST'/$0' {} \;

pushd $DEST
for i in $GCDA/*.gcda
do
   gcov -o . ${i/.gcda/.c}
done

#tar czf $DEST -C $TEMPDIR sys
#rm -rf $TEMPDIR
