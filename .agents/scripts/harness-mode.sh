#!/bin/sh
# harness-mode.sh — print the harness's active mode for a slash-command wrapper's `!` injection.
#
#   sh .agents/scripts/harness-mode.sh
#
# Prints exactly two lines and ALWAYS exits 0:
#   Mode: github | Mode: local | Mode: refused
#   Remote: <git remote get-url origin> | Remote: (none)    -- or, when refused, Reason: <message>
#
# Every issue and epic wrapper injects this in place of `git remote get-url origin`, which exits 2
# in a repository with no origin — exactly the repository local mode is for — and what an agent
# does with a failing injection is not something this harness controls (local-mode spec, Residual
# Unknowns). So a refusal travels as data, `Mode: refused`, for the command to relay before it
# writes anything; never as an exit status. Reading the origin URL reads .git/config, not the
# remote, so it is safe in local mode too.
#
# The config is resolved by harness_config_load (harness-config.sh), from the main checkout even
# when this copy runs inside a linked worktree.

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || SCRIPT_DIR=.agents/scripts
PROJECT_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." 2>/dev/null && pwd) || PROJECT_ROOT=.

# Everything that runs foreign code runs in a subshell: a config with a syntax error, or one that
# calls `exit`, would otherwise take this script's exit status — and its output contract — with it.
# The config's own stdout and stderr are discarded so they cannot add a third line.
_hm_out=$(
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/harness-config.sh" || exit 1
  if harness_config_load "$PROJECT_ROOT" >/dev/null 2>&1; then
    _hm_remote=$(cd "$HARNESS_CONFIG_ROOT" 2>/dev/null && git remote get-url origin 2>/dev/null) || _hm_remote=
    printf 'Mode: %s\nRemote: %s\n' "$HARNESS_MODE" "${_hm_remote:-(none)}"
  else
    printf 'Mode: refused\nReason: %s\n' "$HARNESS_REFUSAL"
  fi
) 2>/dev/null

case "$_hm_out" in
  'Mode: '*) printf '%s\n' "$_hm_out" ;;
  *) printf 'Mode: refused\nReason: %s\n' \
       'could not load the harness config: .agents/scripts/harness-config.sh is missing, or sourcing .agents/harness.config failed' ;;
esac
exit 0
