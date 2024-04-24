#! /usr/bin/env bash

set -eu
set -o pipefail

flake_dir="$1"

contents="$flake_dir/contents.json"

regenerate="$REGENERATE"

locked_url="$(cat "$flake_dir"/locked-url)"

if [[ $regenerate = 1 ]]; then
    store_path="$(nix flake metadata --json "$locked_url" | jq -r .path)"

    if ! [[ -e $store_path/flake.lock ]]; then
        echo "Flake $locked_url is unlocked." >&2
        exit 1
    fi
fi

tmp_dir="$flake_dir/tmp-flake"
rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"

sed "s|c9026fc0-ced9-48e0-aa3c-fc86c4c86df1|$locked_url|" < eval-flake.nix > "$tmp_dir/flake.nix"

if [[ $regenerate = 1 ]]; then
    eval_out="$contents.tmp"
else
    eval_out="$flake_dir/contents-new.json"
fi

echo "Evaluating $locked_url..." >&2

if ! nix eval --no-allow-import-from-derivation --min-free 1000000000 --json "path:$(readlink -f $tmp_dir)#contents" > "$eval_out" 2> "$flake_dir/eval.stderr"; then
    echo "Flake $locked_url failed to evaluate:" >&2
    cat "$flake_dir/eval.stderr" >&2
    exit 1
fi

if [[ $regenerate = 1 ]]; then
    nix --version > "$flake_dir/nix-version"
    mv "$eval_out" "$contents"
else
    if ! cmp -s "$contents" "$eval_out"; then
        echo "Evaluation mismatch on $locked_url." >&2
        git diff --no-index --word-diff=porcelain --word-diff-regex='[^{}:"]+' "$contents" "$eval_out"
        exit 1
    fi
fi

exit 0
