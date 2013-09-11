#!/bin/bash -x

"$S2EDIR/build/qemu-release/x86_64-softmmu/qemu-system-x86_64" -serial stdio "$@"

