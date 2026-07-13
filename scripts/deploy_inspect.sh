#!/usr/bin/env bash

set -euo pipefail

repo_commit=$(git rev-parse HEAD)
echo "Repository: $repo_commit"

for binary in "$HOME/bin/lazygit-next" "$HOME/bin/lazygit"; do
    echo
    echo "$binary"

    if [[ ! -x "$binary" ]]; then
        echo "  binary not found"
        continue
    fi

    info=$("$binary" --version)
    echo "  $info"
    binary_commit=$(sed -n 's/^commit=\([^,]*\).*/\1/p' <<< "$info")

    if [[ -z "$binary_commit" ]] || ! git cat-file -e "$binary_commit^{commit}" 2>/dev/null; then
        echo "  embedded commit is unavailable or not present in this repo"
        continue
    fi

    if git merge-base --is-ancestor "$binary_commit" "$repo_commit"; then
        behind=$(git rev-list --count "$binary_commit..$repo_commit")
        echo "  $behind commits behind this repo"
    else
        echo "  commit is not an ancestor of this repo; cannot determine how many commits behind"
    fi
done
