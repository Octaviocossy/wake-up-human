#!/bin/sh
# local-issues.sh — read the local issues of local mode (USE_GITHUB=false).
#
# A local issue is a plan file under .agents/plans/ whose header carries a line reading exactly
# `> Issue: #local-<n>` (.agents/rules/local-mode.md). This script is the one place that allocates
# their IDs, resolves an ID to its file, and lists them, so no command re-implements the scan.
#
# It only reads: it never writes a plan, never commits, and never touches a remote or GitHub, so it
# is safe in either mode. Callers run it only in local mode.
#
# Usage:
#   sh .agents/scripts/local-issues.sh next-ids <k>        k fresh IDs, one per line (local-<n>)
#   sh .agents/scripts/local-issues.sh find <local-n>      path of the plan whose header is that ID
#   sh .agents/scripts/local-issues.sh list [--open] [--epics]
#                                    TSV: <id> TAB <status> TAB <path> TAB <title>, ordered by <n>
#
# next-ids allocates above the highest <n> in use anywhere it can be seen: every
# `> Issue: #local-<n>` header in .agents/plans/*.md, every local-<n> token in
# `git log --all --format=%B`, and every local branch name. Over-counting only skips a number;
# under-counting would reuse an ID an integrated epic already carries, which would read as done.
#
# Exit codes:
#   0  success
#   1  find: no plan carries that ID
#   2  find: more than one plan carries that ID (their paths are printed on stderr)
#   3  usage error: unknown subcommand, unknown option, or a malformed argument

set -eu

PROJECT_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$PROJECT_ROOT"

PLANS_DIR=.agents/plans

usage_error() {
  echo "local-issues: $1" >&2
  echo "usage: sh .agents/scripts/local-issues.sh next-ids <k> | find <local-n> | list [--open] [--epics]" >&2
  exit 3
}

# Print the highest <n> of any local-<n> token on stdin, or 0. The token counts when the
# character before it is not a letter, digit or underscore, so `#local-9`, `epic/local-3-x` and
# `(local-4-y)` count and `nonlocal-5` does not. "local-" is 6 characters: the digits start at
# RSTART + 6.
max_local_n() {
  awk '
    {
      s = $0
      while (match(s, /local-[0-9]+/)) {
        pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
        if (pre !~ /[A-Za-z0-9_]/) {
          n = substr(s, RSTART + 6, RLENGTH - 6) + 0
          if (n > max) max = n
        }
        s = substr(s, RSTART + RLENGTH)
      }
    }
    END { print max + 0 }
  '
}

next_ids() {
  [ "$#" -eq 1 ] || usage_error "next-ids takes exactly one argument"
  case "$1" in
    ''|*[!0-9]*) usage_error "next-ids: '$1' is not a positive integer" ;;
  esac
  [ "$1" -ge 1 ] || usage_error "next-ids: '$1' is not a positive integer"
  _max=$(
    {
      for _f in "$PLANS_DIR"/*.md; do
        [ -f "$_f" ] || continue
        grep '^> Issue: #local-[0-9]' "$_f" || :
      done
      # Outside a git repository (or before the first commit) there is nothing more to see.
      if git rev-parse --git-dir >/dev/null 2>&1; then
        git log --all --format=%B 2>/dev/null || :
        git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null || :
      fi
    } | max_local_n
  )
  _i=1
  while [ "$_i" -le "$1" ]; do
    printf 'local-%s\n' "$((_max + _i))"
    _i=$((_i + 1))
  done
}

find_issue() {
  [ "$#" -eq 1 ] || usage_error "find takes exactly one ID"
  _id=${1#\#}
  case "$_id" in
    local-*) _n=${_id#local-} ;;
    *) usage_error "find: '$1' is not a local-<n> ID" ;;
  esac
  case "$_n" in
    ''|*[!0-9]*) usage_error "find: '$1' is not a local-<n> ID" ;;
  esac
  _count=0
  _hit=
  for _f in "$PLANS_DIR"/*.md; do
    [ -f "$_f" ] || continue
    # -x -F: the whole line, literally — `> Issue: #local-1` must not match `#local-12`, and
    # nothing may follow the ID (the runner's own grep is anchored the same way).
    if grep -q -x -F "> Issue: #local-$_n" "$_f"; then
      _count=$((_count + 1))
      _hit=$_f
    fi
  done
  case "$_count" in
    0)
      echo "local-issues: no plan in $PLANS_DIR carries '> Issue: #local-$_n'" >&2
      exit 1
      ;;
    1)
      printf '%s\n' "$_hit"
      ;;
    *)
      echo "local-issues: $_count plans carry '> Issue: #local-$_n' — fix the clash by hand:" >&2
      for _f in "$PLANS_DIR"/*.md; do
        [ -f "$_f" ] || continue
        if grep -q -x -F "> Issue: #local-$_n" "$_f"; then
          printf '%s\n' "$_f" >&2
        fi
      done
      exit 2
      ;;
  esac
}

list_issues() {
  _open=0
  _epics=0
  for _a in "$@"; do
    case "$_a" in
      --open) _open=1 ;;
      --epics) _epics=1 ;;
      *) usage_error "list: unknown option '$_a'" ;;
    esac
  done
  # Reuse the positional parameters as the file list: POSIX sh has no arrays, and a plan path
  # never contains a newline but may in principle contain a space.
  set --
  for _f in "$PLANS_DIR"/*.md; do
    [ -f "$_f" ] || continue
    if [ "$_epics" -eq 1 ]; then
      case $(basename -- "$_f") in
        *-epic-local-*.md) ;;
        *) continue ;;
      esac
    fi
    set -- "$@" "$_f"
  done
  [ "$#" -gt 0 ] || return 0
  # One pass over every file. A file is a local issue only if it has a line reading exactly
  # `> Issue: #local-<n>`; its status is the first `> Status: **x**`, its title the first H1.
  # The leading numeric column exists only to sort by <n>; cut drops it.
  awk -v only_open="$_open" '
    function emit() {
      if (id == "") return
      if (only_open == 1 && (status == "completed" || status == "abandoned")) return
      printf "%s\tlocal-%s\t%s\t%s\t%s\n", id, id, status, path, title
    }
    FNR == 1 { emit(); id = ""; status = "unknown"; title = ""; path = FILENAME }
    title == "" && /^# / { title = substr($0, 3); gsub(/\t/, " ", title) }
    id == "" && /^> Issue: #local-[0-9]+$/ { id = substr($0, 17) }
    status == "unknown" && /^> Status: \*\*[^*]+\*\*/ {
      s = $0
      sub(/^> Status: \*\*/, "", s)
      sub(/\*\*.*$/, "", s)
      status = s
    }
    END { emit() }
  ' "$@" | sort -n -k 1,1 | cut -f 2-
}

[ "$#" -ge 1 ] || usage_error "no subcommand given"
_cmd=$1
shift
case "$_cmd" in
  next-ids) next_ids "$@" ;;
  find) find_issue "$@" ;;
  list) list_issues "$@" ;;
  *) usage_error "unknown subcommand '$_cmd'" ;;
esac
