#!/bin/bash

ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${ldir}/lib/common.sh"

if [[ ! -d "$1" ]]
then
	exit 1
fi

commands=("${1}/")
commands+=("${1}/")

add_job () {
	echo '#Next line was added automatically.'
#	echo $@ >> /etc/crontab
	echo $@
}

check_root

for i in ${commands[@]}
do
	add_job '* * * * * root '
	add_job '* * * * * root '
done

