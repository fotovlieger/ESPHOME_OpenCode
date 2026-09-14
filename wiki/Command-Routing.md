# Command Routing

opencode is configured to run **every** shell command through a wrapper:

```json
// workspace/opencode.json
{ "shell": "/usr/local/bin/toolchain" }
```

opencode invokes it as `toolchain -c "<command>"` with the current working directory
set inside the shared workspace. The wrapper then decides whether the command runs
**locally** in the agent container or is forwarded over **SSH** to the toolchain.

## The wrapper

`opencode/toolchain`:

```bash
#!/usr/bin/env bash
set -uo pipefail

is_github_cmd() {
  [[ "$1" =~ (^|[[:space:];&|()])git([[:space:]]|$) ]] || \
  [[ "$1" =~ (^|[[:space:];&|()])gh([[:space:]]|$) ]]
}

is_toolchain_cmd() {
  [[ "$1" =~ (^|[[:space:];&|()])(esphome|esptool|platformio|pio|idf\.py)([[:space:]]|$) ]]
}

if [ "${1:-}" = "-c" ]; then
  shift
  cmd="$*"
  if is_github_cmd "$cmd" && ! is_toolchain_cmd "$cmd"; then
    exec bash -c "$cmd"                       # run locally
  fi
  exec ssh -o LogLevel=ERROR toolchain "cd $(printf %q "$PWD") && $cmd"
fi

exec ssh -o LogLevel=ERROR -t toolchain "$@"  # interactive shell
```

## Routing table

| Command | Runs in | Why |
|---------|---------|-----|
| `git …`, `gh …` (alone) | **opencode** | GitHub token + git config live here |
| `esphome …`, `esptool …`, `pio …`, `idf.py …` | **toolchain** | Real build environment |
| anything else (`ls`, `cat`, `grep`, `python3`, …) | **toolchain** | Default is remote |
| a command mixing `git` **and** `esphome` | **toolchain** | `! is_toolchain_cmd` fails |
| no `-c` (interactive) | **toolchain** | `ssh -t toolchain` |

The `cd $(printf %q "$PWD") && …` part is what makes remote execution transparent:
because `/workspace` is bind-mounted at the same path in both containers, the remote
`cd` lands in the equivalent directory.

## Implications

- **File edits** are *not* done via the shell. opencode's own read/write/edit tools
  operate directly on the mounted `/workspace`, so they are effectively instant and
  visible to both containers.
- **Build output** written by `esphome` (under `.esphome/`) lands on the shared
  mount and is immediately readable by the agent.
- **`git` never touches the toolchain**, so the toolchain never sees a token.

## Sanity checks

From a shell in the agent container:

```bash
toolchain -c 'pwd; esphome version'   # -> /workspace, Version: 2026.8.2 (remote)
toolchain -c 'pwd; git status'        # -> local agent container
```
