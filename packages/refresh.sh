#!/usr/bin/env bash
# Re-dump the package lists from THIS machine, so the next rebuild is current.
#
# This overwrites the curated lists with raw dumps — it does not re-apply the
# repo/AUR split or the Plasma/font trimming that produced the versions in git,
# and it does not check that the names exist in Arch. Diff before committing.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

pacman -Qqen > pacman.raw.txt
pacman -Qqem > aur.raw.txt

echo "wrote packages/pacman.raw.txt ($(wc -l < pacman.raw.txt) native)"
echo "wrote packages/aur.raw.txt    ($(wc -l < aur.raw.txt) foreign)"
echo
echo "new since the curated lists:"
comm -23 <(sort -u pacman.raw.txt aur.raw.txt) \
         <(grep -hvE '^\s*(#|$)' pacman.txt aur.txt | sort -u)
