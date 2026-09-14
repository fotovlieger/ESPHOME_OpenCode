# Architecture

The environment deliberately splits **orchestration** from **execution** into two
containers that share one workspace (developemnt area).

## Why two containers?

| Concern | Lives in | Reason |
|---------|----------|--------|
| Agent reasoning, file edits, git/gh | `opencode` | Only place GitHub credentials exist. Keeps the agent image small and disposable. |
| ESPHome / esptool / platformio builds | `esp-toolchain` | Heavy toolchain (~GBs of Python + Espressif tools) kept isolated and reusable. |
| Project files | `./workspace` (bind mount) | Single source of truth, identical absolute paths in both containers. |

This means you can rebuild or upgrade the agent without touching the toolchain, and
vice versa.

## Network

Both containers join a dedicated bridge network:

```yaml
networks:
  espdev:
    driver: bridge
```

The toolchain container is reachable by its service/host alias `esp-toolchain`
(and `toolchain` as the SSH host alias), so the agent connects with plain SSH and
never needs published ports.

## Data flow

1. **You** attach to the `opencode` container (TUI or shell).
2. The agent edits files under `/workspace/BoilerController` using its file tools.
3. For a build/flash, the agent runs a shell command. Because
   `workspace/opencode.json` sets `"shell": "/usr/local/bin/toolchain"`, the
   command passes through the wrapper ([[Command Routing]]).
4. Non-git commands are forwarded over SSH to `esp-toolchain`, which runs
   `esphome …` from the same `/workspace` path.
5. `esphome` compiles with the Espressif toolchain and writes build output under
   `/workspace/BoilerController/.esphome/` (visible to the agent immediately), then
   uploads to the ESP32 over **OTA** or a **USB serial port** ([[USB Serial Passthrough]]).
6. Git operations run **locally** in the `opencode` container, where the GitHub
   token lives, so commits and pushes authenticate without exposing credentials to
   the toolchain.

## Design properties

- **Same paths, two namespaces.** `cd $(pwd) && …` in the wrapper works because
  `/home/hans/AI/workspace` is mounted at `/workspace` in both containers.
- **Credentials never leave the agent container.** The toolchain only receives the
  agent's *public* SSH key.
- **Toolchain is stateless-ish.** Build caches persist in the `esphome-data` volume
  and `.esphome/`, so it can be recreated freely.
