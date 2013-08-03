#!/bin/bash -x

dir=debian32

IFS=','

packets=(systemtap systemtap-client systemtap-server)
packets+=(wget ca-certificates)
packets+=(grub-pc ncurses-dev linux-image-686-pae)
packets+=(kernel-package fakeroot ncurses-dev)
packets+=(expect git libxml2-utils)

#gcc-python-plugin deps python-devel 
#packets+=(gcc-4.8-plugin-dev) script should install apropriate version of package
packets+=(python-dev python-six python-pygments python-sphinx graphviz)


mkdir -p $dir
sudo debootstrap --arch=i386 --include="${packets[*]}"  --variant=buildd sid $dir

