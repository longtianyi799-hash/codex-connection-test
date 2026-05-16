# codex-connection-test

This repository verifies that the ChatGPT Codex GitHub connector can read and write through the installed GitHub App.

## Diagnose hidden Codex login or plugin options

If Codex no longer shows the login option or plugin controls, a local wrapper, shell startup script, project instruction, or Codex configuration file may be disabling those features before Codex starts.

Run the diagnostic script from this repository:

```bash
./scripts/diagnose-codex-options.sh
```

The script checks:

- whether `codex` is available on `PATH` and which binary is being executed;
- whether a shell alias or function is wrapping `codex`;
- `CODEX_*`, `OPENAI_*`, proxy, Node, and npm environment variables that may affect Codex startup;
- Codex configuration files under `$CODEX_HOME`, `~/.codex`, `~/.config/codex`, and the repository `.codex` directory;
- project instruction files such as `AGENTS.md`, `CODEX.md`, `.codexrc`, `codex.json`, and `codex.toml`;
- common shell startup files such as `.bashrc`, `.profile`, and `.zshrc`.

A warning means the script found a setting that may hide or disable login, auth, app, connector, or plugin behavior. Review the printed file and line number, then remove or comment out the offending setting.

## Quick recovery steps

1. Remove any `codex` alias/function shown by the diagnostic script, or launch the real binary path directly.
2. Temporarily unset suspicious `CODEX_*` environment variables and restart the terminal.
3. Back up and simplify `config.toml` if it disables `login`, `auth`, `apps`, `connectors`, `plugin`, or `plugins`.
4. Remove project instructions that tell Codex to avoid login flows or plugins.
5. Retry from a clean Codex home to confirm the issue is configuration-related:

```bash
CODEX_HOME="$(mktemp -d)" codex
```
