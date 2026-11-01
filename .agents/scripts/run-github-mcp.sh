#!/bin/sh
# Reads GITHUB_TOKEN alone and launches the official GitHub MCP server over stdio. Nothing is
# sourced and nothing else is exported, so no other secret in the project's env files reaches
# the server. Sources, first non-empty wins: the environment, .env.mcp, .env.local, .env.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Prints the value of the last GITHUB_TOKEN assignment in file $1, or nothing. Accepts an
# `export ` prefix, trailing blanks, single or double quotes, and a trailing \r (a file saved
# with CRLF).
read_github_token() {
  _line=$(grep -E '^[[:space:]]*(export[[:space:]]+)?GITHUB_TOKEN=' "$1" 2>/dev/null | tail -n 1 | tr -d '\r')
  _line=${_line%"${_line##*[![:space:]]}"}
  _value=${_line#*GITHUB_TOKEN=}
  case $_value in
    \"*\") _value=${_value#\"}; _value=${_value%\"} ;;
    \'*\') _value=${_value#\'}; _value=${_value%\'} ;;
  esac
  printf '%s' "$_value"
}

_token=${GITHUB_TOKEN:-}
for _file in "$PROJECT_ROOT/.env.mcp" "$PROJECT_ROOT/.env.local" "$PROJECT_ROOT/.env"; do
  [ -n "$_token" ] && break
  [ -f "$_file" ] && _token=$(read_github_token "$_file")
done

if [ -z "$_token" ]; then
  echo "run-github-mcp.sh: GITHUB_TOKEN is not set. Checked, in order: the environment," \
    "$PROJECT_ROOT/.env.mcp, $PROJECT_ROOT/.env.local, $PROJECT_ROOT/.env" >&2
  exit 1
fi

# github-mcp-server reads GITHUB_PERSONAL_ACCESS_TOKEN; map our GITHUB_TOKEN onto it.
GITHUB_PERSONAL_ACCESS_TOKEN=$_token
export GITHUB_PERSONAL_ACCESS_TOKEN

# GUI-launched agents may start with a minimal PATH; make sure Homebrew bins are found.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

# Official GitHub MCP server (github/github-mcp-server), installed via `brew install github-mcp-server`.
exec github-mcp-server stdio
