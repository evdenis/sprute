#!/bin/bash -x

#ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#
#source "${ldir}/lib/common.sh"
#
#load_default_config || exit 1

img_file="$1"
host_shared_folder="$2"

mkdir -p "$host_shared_folder"

# daemonize
qemu-kvm -enable-kvm -fsdev \
local,id=tag1,path="$host_shared_folder",security_model=none \
-device virtio-9p-pci,fsdev=tag1,mount_tag=binaries \
-hda "$img_file"

