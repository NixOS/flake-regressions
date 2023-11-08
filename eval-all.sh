#! /usr/bin/env bash

set -eu

: ${REGENERATE:=0}

export REGENERATE

for i in tests/*/*/*; do
    marker="$i/done"
    if [[ -e $marker ]]; then continue; fi
    if ! ./eval-flake.sh "$i"; then
        touch "$i/failed"
    fi
    touch "$marker"
done
