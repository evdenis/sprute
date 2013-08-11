#!/bin/bash -x

qemu-kvm -enable-kvm -fsdev \
local,id=tag1,path="$HOME/vm_shared",security_model=none \
-device virtio-9p-pci,fsdev=tag1,mount_tag=binaries \
-hda ./test.raw

