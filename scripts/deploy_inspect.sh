#!/usr/bin/env bash

set -euo pipefail

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    cyan=$'\033[36m'
    green=$'\033[32m'
    yellow=$'\033[33m'
    red=$'\033[31m'
    reset=$'\033[0m'
else
    cyan=
    green=
    yellow=
    red=
    reset=
fi

repo_commit=$(git rev-parse HEAD)
next_commit=
stable_commit=
printf '%sRepository: %s%s\n' "$cyan" "$repo_commit" "$reset"

for binary in "$HOME/bin/lazygit-next" "$HOME/bin/lazygit"; do
    echo
    printf '%s%s%s\n' "$cyan" "$binary" "$reset"

    if [[ ! -x "$binary" ]]; then
        printf '  %sDIFFER: binary not found%s\n' "$red" "$reset"
        continue
    fi

    info=$("$binary" --version)
    echo "  $info"
    binary_commit=$(sed -n 's/^commit=\([^,]*\).*/\1/p' <<< "$info")

    if [[ -z "$binary_commit" ]] || ! git cat-file -e "$binary_commit^{commit}" 2>/dev/null; then
        printf '  %sDIFFER: embedded commit is unavailable or not present in this repo%s\n' "$red" "$reset"
        continue
    fi

    if [[ "$binary" == "$HOME/bin/lazygit-next" ]]; then
        next_commit=$binary_commit
    else
        stable_commit=$binary_commit
    fi

    if git merge-base --is-ancestor "$binary_commit" "$repo_commit"; then
        behind=$(git rev-list --count "$binary_commit..$repo_commit")
        if (( behind == 0 )); then
            printf '  %sMATCH: same commit%s\n' "$green" "$reset"
        else
            printf '  %sDIFFER: %s commits behind this repo%s\n' "$yellow" "$behind" "$reset"
        fi
    else
        printf '  %sDIFFER: commit is not an ancestor of this repo; cannot determine how many commits behind%s\n' "$yellow" "$reset"
    fi
done

echo
if [[ -n "$next_commit" && -n "$stable_commit" ]]; then
    if [[ "$next_commit" == "$stable_commit" ]]; then
        printf '%sNext and non-next binaries: MATCH%s\n' "$green" "$reset"
    else
        printf '%sNext and non-next binaries: DIFFER%s\n' "$yellow" "$reset"
        printf '  next:     %s\n' "$next_commit"
        printf '  non-next: %s\n' "$stable_commit"
    fi
else
    printf '%sNext and non-next binaries: DIFFER: unable to compare%s\n' "$red" "$reset"
fi
