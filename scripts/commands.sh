#!/bin/bash -x

DIR=/root/


compile_kernel () {
   # link from main page
	local LINK="http://www.kernel.org/$(wget -q -O - http://www.kernel.org | xmllint --recover --xpath '//*[@id="latest_link"]/a/@href' --html - 2>/dev/null | cut -d '"' -f 2)"
   # kernel archive file name from link
   local KFILE="$(echo $LINK | grep -o -e 'linux-.*$')"
   # kernel source directory after unpacking
   local KDIR="$(echo $KFILE | grep -o -e 'linux-[\.[:digit:]]\+[[:digit:]]')"
   # latest(by installation time, not by version) available kernel config file;
   # FIXME: by version
   local KCONFIG=$(ls -1 -t /boot/config-* | head -n 1)

   pushd $DIR

   wget -q $LINK
   tar xf $KFILE
   cd $KDIR

   cp $KCONFIG .config
   #yes '' | make oldconfig > /dev/null
   #make olddefconfig
   make silentoldconfig

   popd
}

#useradd -G sudo,stapdev,stapusr,stapsys -m -s /bin/bash s2e


