#!/bin/bash

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"


crontab="/etc/crontab"

if [[ ! -d "$1" ]]
then
   echo "Directory should be set." 2>&1
	exit 1
fi

commands=("${1}/gccpython.sh")
commands+=("${1}/kernel.sh")



add_job () {
	echo '#Next line was added automatically.' >> $crontab
	echo "$@" >> $crontab
}


check_root

for i in "${commands[@]}"
do
   grep -qFe "${i}" $crontab || { add_job '0 */1 * * * root ' "${i}"; }
done

