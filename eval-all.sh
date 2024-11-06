#! /usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"

cd "$SCRIPT_DIR"

echo "Nix version:"
nix --version

: ${REGENERATE:=0}

export REGENERATE

status=0

flakes=$(find tests -mindepth 3 -maxdepth 3 -type d -not -path '*/.*' | sort | head -n${MAX_FLAKES:-1000000})

for flake in $flakes; do
    marker="$flake/done"
    if [[ ! -e $marker ]]; then
        if ! ./eval-flake.sh "$flake"; then
            touch "$flake/failed"
        fi
    fi
    if [[ -e $flake/failed ]]; then
        echo "❌ $flake"
    else
        echo "✅ $flake"
    fi
    touch "$marker"
done
