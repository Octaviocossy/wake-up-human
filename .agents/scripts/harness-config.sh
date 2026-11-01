#!/bin/sh
# harness-config.sh — load the harness's per-machine config, .agents/harness.config (ADR-0023).
#
# A library: SOURCE it, never run it. Every entry point that reads the config goes through it, so
# the runner, the review dispatcher and the slash commands (via harness-mode.sh) cannot disagree
# about which file counts or what an invalid value means.
#
#   . "$PROJECT_ROOT/.agents/scripts/harness-config.sh"
#   harness_config_load "$PROJECT_ROOT" || exit <n>
#
# harness_config_load <start-dir> resolves the config root (harness_config_root, below), then:
#   .agents/harness.config exists         -> source it (.agents/parallel.config beside it is ignored)
#   only .agents/parallel.config exists   -> refuse: the rename is forced, never bridged
#   neither exists                        -> the caller's defaults stand
# then validates USE_GITHUB: unset or empty -> true; exactly true or false -> accepted; anything
# else -> refuse, naming the value, so a typo can neither publish to GitHub nor go silently local.
#
# It sets, in the caller's shell:
#   HARNESS_CONFIG_ROOT  the directory whose .agents/ was consulted
#   HARNESS_CONFIG_FILE  the file sourced, or empty when there was none
#   USE_GITHUB           normalized to true or false (on success)
#   HARNESS_MODE         github | local (on success); empty on refusal
#   HARNESS_REFUSAL      the reason (on refusal); empty on success
# Returns 0 on success. On refusal it prints "refused: <HARNESS_REFUSAL>" to stderr and returns 1.
#
# The config is plain sh, sourced into the caller's shell: whatever it sets overrides the caller's
# defaults, and an exported USE_GITHUB applies only when the file does not set it — the precedence
# every runner knob already has. POSIX sh only: no `local`, so helper variables carry an _hc_
# prefix to stay out of the caller's namespace.

# harness_config_root <start-dir>
# Prints the directory whose .agents/ holds the config: the MAIN worktree's copy of <start-dir>.
# The config is gitignored, so it exists only in the main checkout, never in a linked worktree
# (.worktrees/<branch>): a script running from a worktree's copy of .agents/scripts/ must still
# read the main checkout's file, or the mode would silently fall back to the defaults there. The
# main worktree is the parent of the common git dir; --show-prefix keeps a scaffold that lives in
# a subdirectory of its repository pointing at that subdirectory. Falls back to <start-dir> outside
# git, and whenever the candidate carries no .agents/ (a bare main repository, a submodule's
# modules dir).
harness_config_root() {
  _hc_start=$(CDPATH='' cd -- "${1:-.}" 2>/dev/null && pwd) || _hc_start=${1:-.}
  _hc_common=$(cd "$_hc_start" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null) || _hc_common=
  _hc_prefix=$(cd "$_hc_start" 2>/dev/null && git rev-parse --show-prefix 2>/dev/null) || _hc_prefix=
  if [ -n "$_hc_common" ]; then
    _hc_main=$(cd "$_hc_start" && CDPATH='' cd -- "$_hc_common/.." 2>/dev/null && pwd) || _hc_main=
    if [ -n "$_hc_main" ]; then
      _hc_main=${_hc_main%/}/$_hc_prefix
      _hc_main=${_hc_main%/}
      if [ -d "$_hc_main/.agents" ]; then
        printf '%s\n' "$_hc_main"
        return 0
      fi
    fi
  fi
  printf '%s\n' "$_hc_start"
}

harness_config_load() {
  HARNESS_MODE=
  HARNESS_REFUSAL=
  HARNESS_CONFIG_FILE=
  HARNESS_CONFIG_ROOT=$(harness_config_root "${1:-.}")
  if [ -f "$HARNESS_CONFIG_ROOT/.agents/harness.config" ]; then
    HARNESS_CONFIG_FILE="$HARNESS_CONFIG_ROOT/.agents/harness.config"
    # A non-zero status is refused like an invalid value: under bash's sh, a syntax error in the
    # file aborts the rest of it without exiting, so a USE_GITHUB below the error would never be
    # read and the mode would silently fall back to github. (dash exits the shell outright.)
    # shellcheck disable=SC1090
    if ! . "$HARNESS_CONFIG_FILE"; then
      HARNESS_REFUSAL='sourcing .agents/harness.config failed; fix the file (it is plain sh, one VAR=value per line) and re-run'
      printf 'refused: %s\n' "$HARNESS_REFUSAL" >&2
      return 1
    fi
  elif [ -f "$HARNESS_CONFIG_ROOT/.agents/parallel.config" ]; then
    HARNESS_REFUSAL='rename .agents/parallel.config to .agents/harness.config (mv .agents/parallel.config .agents/harness.config)'
    printf 'refused: %s\n' "$HARNESS_REFUSAL" >&2
    return 1
  fi
  case "${USE_GITHUB:-}" in
    ''|true) USE_GITHUB=true; HARNESS_MODE=github ;;
    false)   HARNESS_MODE=local ;;
    *)
      HARNESS_REFUSAL="USE_GITHUB='$USE_GITHUB' is neither true nor false; set USE_GITHUB=true or USE_GITHUB=false in .agents/harness.config (unset or empty means true)"
      printf 'refused: %s\n' "$HARNESS_REFUSAL" >&2
      return 1
      ;;
  esac
  return 0
}
