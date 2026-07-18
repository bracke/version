#!/bin/sh
# Compare `version <args>` against `git <args>` in identical fixtures.
#
# Usage: compare.sh <fixture-script> <case-file>
#
# The fixture script is run (with $PWD a fresh repo) to build the state; the
# case file holds one argument line per case. Each case runs in its own pair
# of pristine clones of the fixture, so cases cannot contaminate each other.
#
# HOME is isolated: the user's ~/.gitconfig sets diff.algorithm=histogram and
# merge.conflictstyle=diff3, which silently changes git's output and has
# faked "bugs" before.
set -u
FIXTURE=$(realpath "$1"); CASES=$(realpath "$2")
V=${V:-/home/bent/Projekte/Ada/version/bin/main}
WORK=$(mktemp -d); H=$(mktemp -d)
export HOME=$H LC_ALL=C GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_DATE='1700000000 +0000' GIT_COMMITTER_DATE='1700000000 +0000'
n=0; same=0; diffs=0

build () {  # $1 = target dir
  rm -rf "$1"; mkdir -p "$1"; ( cd "$1" && git init -q -b main . \
    && git config user.email t@e && git config user.name T \
    && . "$FIXTURE" ) >/dev/null 2>&1
}

while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  n=$((n+1))
  build "$WORK/g"; build "$WORK/o"
  ( cd "$WORK/g" && eval "git $line"  ) > "$WORK/g.out" 2> "$WORK/g.err"; gr=$?
  ( cd "$WORK/o" && eval "\"$V\" $line" ) > "$WORK/o.out" 2> "$WORK/o.err"; orr=$?
  # Compare stdout and exit status; stderr wording is house style, so only
  # its emptiness is compared.
  ge=$([ -s "$WORK/g.err" ] && echo 1 || echo 0)
  oe=$([ -s "$WORK/o.err" ] && echo 1 || echo 0)
  if cmp -s "$WORK/g.out" "$WORK/o.out" && [ "$gr" = "$orr" ] && [ "$ge" = "$oe" ]; then
    same=$((same+1))
  else
    diffs=$((diffs+1))
    printf '  DIFF  %s\n' "$line"
    [ "$gr" = "$orr" ] || printf '        exit: git=%s ours=%s\n' "$gr" "$orr"
    diff "$WORK/g.out" "$WORK/o.out" 2>/dev/null | head -6 | sed 's/^/        /'
    [ "$ge" = "$oe" ] || printf '        stderr: git=%s ours=%s lines\n' \
      "$(wc -l < "$WORK/g.err")" "$(wc -l < "$WORK/o.err")"
  fi
done < "$CASES"
printf '%s: %d cases, %d match, %d differ\n' "$(basename "$CASES" .cases)" "$n" "$same" "$diffs"
rm -rf "$WORK" "$H"
