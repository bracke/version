#!/bin/sh
# Run every parity suite listed in suites.txt and summarise.
#
# Usage: tools/parity/run_all.sh [name-filter]
#
# Each suite records how many of its cases are KNOWN to diverge from git (the
# fourth field of suites.txt). A suite passes when it diverges no more than
# that, so newly written coverage can land red without wedging the gate, while
# any regression -- or any case that starts diverging that did not before --
# still fails the run. Lower the number as bugs get fixed; never raise it to
# make a failure go away.
#
# A name filter runs only the suites whose case file contains that substring
# ("tools/parity/run_all.sh status").
set -u
HERE=$(dirname "$0")
FILTER=${1:-}
total=0; matched=0; differed=0; known=0; suites=0; failed=''; improved=''

while read -r fixture cases subdir expected; do
  case "$fixture" in ''|\#*) continue ;; esac
  case "$cases" in '') continue ;; esac
  [ "${subdir:-}" = "-" ] && subdir=''
  expected=${expected:-0}

  if [ -n "$FILTER" ]; then
    case "$cases" in *"$FILTER"*) ;; *) continue ;; esac
  fi

  if [ ! -f "$HERE/$fixture" ] || [ ! -f "$HERE/$cases" ]; then
    printf 'MISSING  %s %s\n' "$fixture" "$cases"
    failed="$failed $cases"
    continue
  fi

  suites=$((suites+1))
  out=$(SUBDIR=${subdir:-} sh "$HERE/compare.sh" "$HERE/$fixture" "$HERE/$cases" 2>&1)
  line=$(echo "$out" | tail -1)

  n=$(echo "$line" | sed 's/.*: \([0-9]*\) cases.*/\1/')
  m=$(echo "$line" | sed 's/.*cases, \([0-9]*\) match.*/\1/')
  k=$(echo "$line" | sed 's/.*match, \([0-9]*\) differ.*/\1/')
  total=$((total+n)); matched=$((matched+m)); differed=$((differed+k))
  known=$((known+expected))

  if [ "$k" -gt "$expected" ]; then
    # Only a suite that got worse is worth printing the detail for.
    echo "$out" | grep -v ': [0-9]* cases,'
    printf '%s   REGRESSED (%d known)\n' "$line" "$expected"
    failed="$failed $cases"
  elif [ "$k" -lt "$expected" ]; then
    printf '%s   improved (%d known -- lower it in suites.txt)\n' "$line" "$expected"
    improved="$improved $cases"
  else
    printf '%s\n' "$line"
  fi
done < "$HERE/suites.txt"

echo
printf 'TOTAL: %d suites, %d cases, %d match, %d differ (%d known)\n' \
  "$suites" "$total" "$matched" "$differed" "$known"
[ -n "$improved" ] && printf 'now better than recorded:%s\n' "$improved"
if [ -n "$failed" ]; then
  printf 'REGRESSED:%s\n' "$failed"
  exit 1
fi
