#!/bin/bash -x

mode="release"

case "$1" in
   "release")
      shift;;
   "debug")
      mode="debug";
      shift;;
esac

log="$(mktemp)"
errlog="$(mktemp)"

trap "{ mv '$log' ./s2e-last/run.log; mv '$errlog' ./s2e-last/err.log; }" EXIT

"${S2EDIR}/build/qemu-${mode}/x86_64-s2e-softmmu/qemu-system-x86_64" -serial stdio "$@" > >( tee "$log" ) 2> >( tee "$errlog" >&2 )

