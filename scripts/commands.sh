#!/bin/bash -x



get_latest_stable_kernel () {
	local LINK="http://www.kernel.org/$(wget -q -O - http://www.kernel.org | xmllint --recover --xpath '//*[@id="latest_link"]/a/@href' --html - 2>/dev/null | cut -d '"' -f 2)"
	
	wget $LINK
}

useradd -G sudo,stapdev,stapusr,stapsys -m -s /bin/bash s2e
cd /home/s2e/
get_latest_stable_kernel &&
tar xf linux*.tar.xf


