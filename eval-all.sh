#! /usr/bin/env bash

set -eu

script_dir="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"

cd "$script_dir"

echo "Nix version: $(nix --version)"

export CACHE_RUNS=1

nix store info

find tests -mindepth 3 -maxdepth 3 -type d -ipath "tests/${FLAKE_REGRESSION_GLOB:-*}" -not -path '*/.*' | sort | head -n${MAX_FLAKES:-1000000} | parallel ./eval-flake.sh
