#!/bin/bash -x

DIR=debian32

mkdir -p $DIR
sudo debootstrap --arch=i386 --include=systemtap,systemtap-client,systemtap-server,grub-pc,fakeroot,wget,ca-certificates,libxml2-utils,ncurses-dev,linux-image-686-pae,expect  --variant=buildd sid $DIR

