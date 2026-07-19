#!/bin/sh
# Which commands the parity suites actually exercise.
#
# Usage: tools/parity/coverage.sh [-u]
#
# Green cases prove only that what someone thought to test still works, so the
# useful number is not how many cases pass but how many commands no case ever
# names. -u lists just the uncovered ones, for piping into the next round of
# case-writing.
set -u
HERE=$(dirname "$0")
CLI=$HERE/../../src/version-cli.adb
TMP=$(mktemp -d)

# Every command the CLI dispatches on.
grep -oE '^[[:space:]]*(elsif|if) Command = "[a-z0-9-]+"' "$CLI" \
  | grep -oE '"[a-z0-9-]+"' | tr -d '"' | sort -u > "$TMP/all"

# Every command named as the first word of a case line.
cat "$HERE"/*.cases 2>/dev/null \
  | grep -vE '^[[:space:]]*(#|$)' | awk '{print $1}' | sort -u > "$TMP/seen"

# Commands this CLI spells differently from git; a case naming git's spelling
# covers ours, so credit both.
{ cat "$TMP/seen"
  while read -r c; do
    case "$c" in
      add) echo stage ;; commit) echo save ;;
      rm)  echo remove ;; fsck) echo verify ;;
    esac
  done < "$TMP/seen"
} | sort -u > "$TMP/covered"

comm -12 "$TMP/all" "$TMP/covered" > "$TMP/hit"
comm -23 "$TMP/all" "$TMP/covered" > "$TMP/miss"

if [ "${1:-}" = "-u" ]; then
  cat "$TMP/miss"
else
  printf 'commands dispatched: %s\n' "$(wc -l < "$TMP/all" | tr -d ' ')"
  printf 'exercised by a case: %s\n' "$(wc -l < "$TMP/hit" | tr -d ' ')"
  printf 'never exercised:     %s\n\n' "$(wc -l < "$TMP/miss" | tr -d ' ')"
  echo 'uncovered:'
  fmt -w 76 < "$TMP/miss" | sed 's/^/  /'
fi
rm -rf "$TMP"
