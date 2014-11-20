#!/bin/bash -x

mode="release"

case "$1" in
   "release")
      shift;;
   "debug")
      mode="debug";
      shift;;
esac

typeset -i init_timestamp=$(stat --printf='%X' ./s2e-last/)

log="$(mktemp)"
errlog="$(mktemp)"

trap "{ if (( $init_timestamp < \$(stat --printf='%X' ./s2e-last/) )); then mv '$log' ./s2e-last/run.log; mv '$errlog' ./s2e-last/err.log; else rm -f '$log' '$errlog'; fi; }" EXIT
sleep 1s

"${S2EDIR}/build/qemu-${mode}/x86_64-s2e-softmmu/qemu-system-x86_64" -serial stdio "$@" > >( tee "$log" ) 2> >( tee "$errlog" >&2 )

