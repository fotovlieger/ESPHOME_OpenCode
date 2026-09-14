# Containers

Defined in `~/AI/docker-compose.yml`. The compose project is named **`ai`**, which
is why the named volumes are `ai_opencode-home` and `ai_esphome-data`.

## `opencode` — the agent

| | |
|---|---|
| Image | `ai-opencode:latest` (built from `opencode/Dockerfile`) |
| Base | `ghcr.io/anomalyco/opencode:latest` |
| Container name | `opencode` |
| User | `1000:1000` (`opencode`) |
| Working dir | `/workspace` |
| Depends on | `toolchain` |

**Image contents** (on top of the base): `openssh-client`, `git`, `github-cli`,
`curl`, `jq`, `bash`, `sudo`; a UID/GID-1000 `opencode` user with passwordless
sudo; a global SSH config; and the `toolchain` wrapper at
`/usr/local/bin/toolchain`.

**Mounts**

| Host | Container | Mode |
|------|-----------|------|
| `./workspace` | `/workspace` | rw |
| `opencode-home` (volume) | `/home/opencode` | rw |
| `./.gitconfig/.gitconfig` | `/home/opencode/.gitconfig` | ro |
| `./ssh/id_ed25519` | `/home/opencode/.ssh/id_ed25519` | ro |
| `./ssh/id_ed25519.pub` | `/home/opencode/.ssh/id_ed25519.pub` | ro |

**Environment**

```
HOME=/home/opencode
GITHUB_TOKEN / GH_TOKEN        # from ~/AI/.env
GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL
GIT_COMMITTER_NAME / GIT_COMMITTER_EMAIL
```

The git credential helper turns `GITHUB_TOKEN` into HTTPS auth:

```ini
[credential]
    helper = "!f() { echo username=x-access-token; echo password=$GITHUB_TOKEN; }; f"
```

`stdin_open` + `tty` are enabled so you can `docker attach opencode`.

## `esp-toolchain` — the build/flash host

| | |
|---|---|
| Image | `ai-toolchain:latest` (built from `toolchain/Dockerfile`) |
| Base | `ubuntu:24.04` |
| Container name | `esp-toolchain` |
| User | root entrypoint, `toolchain` (1000) for SSH |
| Working dir | `/workspace` |

**Image contents**: `python3`, `build-essential`, `cmake`, `ninja-build`,
`openssh-server`, `sudo`, `usbutils`; a virtualenv at `/opt/esphome` with
**esphome** and **esptool**; symlinks `/usr/local/bin/esphome` and
`/usr/local/bin/esptool`; and `entrypoint.sh`.

**Mounts**

| Host | Container | Mode |
|------|-----------|------|
| `./workspace` | `/workspace` | rw |
| `esphome-data` (volume) | `/root/.esphome` | rw |
| `./ssh/id_ed25519.pub` | `/tmp/opencode_id_ed25519.pub` | ro |

**Device access** (see [[USB Serial Passthrough]]):

```yaml
device_cgroup_rules:
  - 'c 188:* rmw'   # ttyUSB*  (CP210x, CH340, …)
  - 'c 166:* rmw'   # ttyACM*  (native USB / USB-Serial-JTAG)
```

**Entrypoint** (`toolchain/entrypoint.sh`):

1. Installs the agent's public key into `/home/toolchain/.ssh/authorized_keys`.
2. Forces key-only SSH (`PasswordAuthentication no`).
3. Starts `sshd`.
4. Starts the serial-node watcher ([[USB Serial Passthrough]]).
5. `exec tail -f /dev/null` to keep the container alive.

## SSH between the containers

`opencode/ssh_config` is copied to `/etc/ssh/ssh_config` in the agent image:

```
Host toolchain
    HostName esp-toolchain
    User toolchain
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

So `ssh toolchain` resolves to the `esp-toolchain` container and authenticates with
the mounted private key.

## opencode configuration

- **Global** (`~/.config/opencode/opencode.json` in the agent): `autoupdate: false`,
  default agent `deepseek-main`.
- **Workspace** (`workspace/opencode.json`): sets the model, the
  `deepseek/deepseek-v4-flash` default, and crucially:

  ```json
  { "shell": "/usr/local/bin/toolchain" }
  ```

  This is what makes every shell command pass through the router.
