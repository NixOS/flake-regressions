#! /usr/bin/env bash

set -eu
set -o pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

flake_dir="$1"

marker="$flake_dir/done"
failed="$flake_dir/failed"
contents="$flake_dir/contents.json"

if [[ -e "$flake_dir/disabled" ]]; then
    printf "🚫 $flake_dir\n" >&2
    exit 0
fi

error_handler() {
    printf "❌ $flake_dir\n" >&2
    touch "$failed"
}
trap error_handler ERR

show_success() {
    local extra="$1"
    printf "✅ $flake_dir $extra\n" >&2
}

if [[ ${CACHE_RUNS:-0} = 1 && -e $marker ]]; then
    [[ ! -e $failed ]]
    show_success
    exit 0
fi

regenerate="${REGENERATE:-0}"
prefetch="${PREFETCH:-0}"
use_show="${USE_NIX_FLAKE_SHOW:-0}"

if [[ -e "$flake_dir"/flake.nix ]]; then
    locked_url="path:$(realpath "$flake_dir")"
else
    locked_url="$(cat "$flake_dir"/locked-url)"
fi

if [[ $regenerate = 1 ]]; then
    eval_out="$contents.tmp"
else
    eval_out="$flake_dir/contents-new.json"
fi

rm -f "$eval_out" "$flake_dir/eval.stderr"

if [[ $prefetch = 1 ]]; then
    echo "Prefetching $locked_url..." >&2
    if ! nix flake prefetch-inputs "$locked_url" > "$flake_dir/prefetch.stderr" 2>&1; then
        echo "Flake $locked_url failed to prefetch:" >&2
        cat "$flake_dir/prefetch.stderr" >&2
        # This is not a fatal error since some inputs are unused.
    fi
fi

echo "Evaluating $locked_url..." >&2

if [[ $use_show = 1 ]]; then

    if ! command time -f 'elapsed=%e user=%U kernel=%S mem=%M' -o "$flake_dir/eval.timings" nix flake show --show-trace --no-allow-import-from-derivation --min-free 1000000000 --json --no-update-lock-file --all-systems --output-paths --drv-paths --no-eval-cache "$locked_url" >> "$eval_out" 2>> "$flake_dir/eval.stderr"; then
        echo "Flake $locked_url failed to evaluate:" >&2
        cat "$flake_dir/eval.stderr" >&2
        error_handler
        exit 1
    fi

else

    tmp_dir="$flake_dir/tmp-flake"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    sed "s|c9026fc0-ced9-48e0-aa3c-fc86c4c86df1|$locked_url|" < $script_dir/eval-flake.nix > "$tmp_dir/flake.nix"

    if ! command time -f 'elapsed=%e user=%U kernel=%S mem=%M' -o "$flake_dir/eval.timings" nix eval --show-trace --no-allow-import-from-derivation --min-free 1000000000 --json "path:$(realpath "$tmp_dir")#contents" >> "$eval_out" 2>> "$flake_dir/eval.stderr"; then
        echo "Flake $locked_url failed to evaluate:" >&2
        cat "$flake_dir/eval.stderr" >&2
        error_handler
        exit 1
    fi

fi

if [[ $regenerate = 1 ]]; then
    nix --version > "$flake_dir/nix-version"
    mv "$eval_out" "$contents"
else
    if ! cmp -s "$contents" "$eval_out"; then
        printf "Evaluation mismatch on %s." "$locked_url." >&2
        git diff --no-index --word-diff=porcelain --word-diff-regex='[^{}:"]+' "$contents" "$eval_out"
        error_handler
        exit 1
    fi
fi

show_success "[$(cat "$flake_dir/eval.timings")]"

exit 0
