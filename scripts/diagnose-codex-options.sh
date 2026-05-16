#!/usr/bin/env bash
set -u

printf '%s\n' 'Codex login/plugin option diagnostic'
printf '%s\n' '===================================='
printf 'Date: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'Shell: %s\n' "${SHELL:-unknown}"
printf 'HOME: %s\n' "${HOME:-unknown}"
printf 'CODEX_HOME: %s\n' "${CODEX_HOME:-<not set>}"
printf '\n'

warn_count=0
info_count=0

warn() {
  warn_count=$((warn_count + 1))
  printf 'WARN: %s\n' "$1"
}

info() {
  info_count=$((info_count + 1))
  printf 'INFO: %s\n' "$1"
}

section() {
  printf '\n## %s\n' "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

scan_file() {
  local file=$1
  [ -f "$file" ] || return 0

  local matches
  matches=$(awk '
    BEGIN { IGNORECASE = 1 }
    /CODEX_HOME|OPENAI_API_KEY|CODEX_[A-Z0-9_]*|codex[[:space:]].*(--profile|--config|features|login|plugin|plugins)|features[[:space:]]+disable|disable.*(login|auth|oauth|plugin|plugins|apps|connectors)|plugins?[[:space:]]*=[[:space:]]*false|apps?[[:space:]]*=[[:space:]]*false|connectors?[[:space:]]*=[[:space:]]*false|auth[[:space:]]*=[[:space:]]*false|login[[:space:]]*=[[:space:]]*false/ {
      printf "  %s:%d:%s\n", FILENAME, FNR, $0
    }
  ' "$file")

  if [ -n "$matches" ]; then
    warn "Potential Codex-affecting setting found in $file"
    printf '%s\n' "$matches"
  fi
}

section 'Codex binary and version'
if command_exists codex; then
  codex_path=$(command -v codex)
  printf 'codex path: %s\n' "$codex_path"
  if codex --version >/tmp/codex-version.$$ 2>/tmp/codex-version-err.$$; then
    sed 's/^/  /' /tmp/codex-version.$$
  else
    warn 'codex --version failed; inspect PATH aliases/wrappers and installation.'
    sed 's/^/  stderr: /' /tmp/codex-version-err.$$
  fi
  rm -f /tmp/codex-version.$$ /tmp/codex-version-err.$$
else
  warn 'codex executable was not found on PATH.'
fi

section 'Shell aliases and functions'
if alias codex >/tmp/codex-alias.$$ 2>/dev/null; then
  warn 'A shell alias named codex exists and may hide login/plugin options.'
  sed 's/^/  /' /tmp/codex-alias.$$
else
  info 'No codex alias found in this shell.'
fi
rm -f /tmp/codex-alias.$$

if command_exists type; then
  type -a codex 2>/dev/null | sed 's/^/  /' || true
fi

section 'Environment variables'
env | sort | awk '
  BEGIN { IGNORECASE = 1 }
  /^(CODEX_|OPENAI_|HTTP_PROXY=|HTTPS_PROXY=|ALL_PROXY=|NO_PROXY=|NODE_OPTIONS=|NPM_CONFIG_)/ {
    print "  " $0
  }
' || true

if env | awk 'BEGIN { IGNORECASE = 1 } /CODEX_.*(DISABLE|NO_|FEATURE|PLUGIN|APP|CONNECT|LOGIN|AUTH)/ { found=1 } END { exit found ? 0 : 1 }'; then
  warn 'One or more CODEX_* variables look capable of disabling features. Temporarily unset them and restart Codex.'
fi

section 'Codex configuration files'
codex_home=${CODEX_HOME:-$HOME/.codex}
config_candidates=(
  "$codex_home/config.toml"
  "$codex_home/config.json"
  "$HOME/.config/codex/config.toml"
  "$HOME/.config/codex/config.json"
  "$PWD/.codex/config.toml"
  "$PWD/.codex/config.json"
)

for candidate in "${config_candidates[@]}"; do
  if [ -f "$candidate" ]; then
    printf 'Found config: %s\n' "$candidate"
    scan_file "$candidate"
  fi
done

section 'Project and agent instruction files'
while IFS= read -r instruction_file; do
  scan_file "$instruction_file"
done < <(find "$PWD" -name AGENTS.md -o -name CODEX.md -o -name '.codexrc' -o -name 'codex.json' -o -name 'codex.toml' 2>/dev/null)

section 'Shell startup scripts'
shell_files=(
  "$HOME/.bashrc"
  "$HOME/.bash_profile"
  "$HOME/.profile"
  "$HOME/.zshrc"
  "$HOME/.zprofile"
  "$HOME/.config/fish/config.fish"
)
for shell_file in "${shell_files[@]}"; do
  scan_file "$shell_file"
done

section 'Suggested remediation'
cat <<'REMEDIATION'
1. If an alias/function wraps `codex`, remove it or run the real binary path printed above.
2. If shell startup files export CODEX_* disable flags, comment them out, open a new terminal, and retry `codex login`.
3. If config.toml disables plugins/apps/connectors/auth/login, back it up and remove those keys, then restart Codex.
4. If a project AGENTS.md or CODEX.md tells Codex to avoid plugins or login flows, remove that project-specific instruction.
5. If the UI still hides login/plugin entries, start a clean session with a temporary home:
   CODEX_HOME="$(mktemp -d)" codex
REMEDIATION

printf '\nSummary: %d warning(s), %d informational note(s).\n' "$warn_count" "$info_count"
if [ "$warn_count" -gt 0 ]; then
  exit 1
fi
