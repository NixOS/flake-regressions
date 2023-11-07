#! /usr/bin/env bash

set -eu

for i in tests/*/*/*; do
    marker="$i/done"
    if [[ -e $marker ]]; then continue; fi
    if REGENERATE=1 ./eval-flake.sh "$i"; then
        touch "$marker"
    fi
done
