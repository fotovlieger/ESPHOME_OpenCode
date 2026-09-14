# Persistence and Restart

What survives what, and how to bring the environment back after a reboot.

## What is persistent

| Item | Persists? | Where |
|------|-----------|-------|
| `docker-compose.yml`, Dockerfiles, `entrypoint.sh`, wrapper | ✅ | host files under `~/AI` |
| Built images `ai-opencode:latest`, `ai-toolchain:latest` | ✅ | local Docker image store |
| `opencode-home` volume (agent home, sessions, `auth.json`) | ✅ | `ai_opencode-home` |
| `esphome-data` volume (`/root/.esphome`, toolchain cache) | ✅ | `ai_esphome-data` |
| Project files | ✅ | `./workspace` bind mount |
| `/dev/ttyUSB*` / `ttyACM*` nodes in the toolchain | ♻️ ephemeral | recreated by the entrypoint watcher on every start |

The serial nodes are intentionally not persisted — they live in the container's
tmpfs and are regenerated from `/sys` on start and on hotplug ([[USB Serial Passthrough]]).

## Recreating containers

`docker compose up -d` (no `--build`) recreates containers from the existing images,
so the entrypoint fix is retained. Use `--build` only when a Dockerfile or
`entrypoint.sh` changed:

```bash
cd ~/AI
docker compose up -d --build          # both services
docker compose up -d --build toolchain  # toolchain only
```

Named volumes are **not** removed by `up`, `down`, or container recreation. Only
`docker compose down -v` deletes them.

## Across a host reboot

The environment does **not** currently start automatically:

- the `docker` systemd unit is **disabled** at boot, and
- both containers have `RestartPolicy=no` with no `restart:` key in the compose file.

After a reboot, start it manually:

```bash
cd ~/AI
docker compose up -d
```

### Making it boot-persistent

```bash
sudo systemctl enable --now docker
```

Then add a restart policy to each service in `docker-compose.yml`:

```yaml
services:
  opencode:
    restart: unless-stopped
  toolchain:
    restart: unless-stopped
```

Apply with:

```bash
docker compose up -d
```

## Useful lifecycle commands

```bash
docker compose ps                     # status
docker compose logs -f toolchain      # toolchain logs (entrypoint output)
docker compose restart toolchain      # recreate the serial watcher
docker compose down                   # stop + remove containers (volumes kept)
docker compose down -v                # DANGER: also deletes both volumes
```
