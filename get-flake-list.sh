#! /usr/bin/env bash

set -e
set -o pipefail

fh list flakes --json | jq -r 'map("https://flakehub.com/f/" + .org + "/" + .project + "/*") | .[]' > all-flakes

while read url; do
    if locked_url="$(nix flake metadata --json "$url" | jq -r .url)"; then
        if [[ $locked_url =~ ^https://api.flakehub.com/f/pinned/([^/]+)/([^/]+)/([^/]+)/ ]]; then
            echo "$url -> $locked_url"
            owner="${BASH_REMATCH[1]}"
            repo="${BASH_REMATCH[2]}"
            version="${BASH_REMATCH[3]}"
            dir="tests/$owner/$repo/$version"
            mkdir -p "$dir"
            printf "%s" "$locked_url" > "$dir/locked-url"
        fi
    fi
done < all-flakes
