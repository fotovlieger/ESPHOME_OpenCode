# Troubleshooting

## `esphome: command not found` or the wrapper fails

The `toolchain` wrapper only exists **inside the opencode container** (it is copied
to `/usr/local/bin/toolchain` by `opencode/Dockerfile`). `workspace/opencode.json`
sets `"shell": "/usr/local/bin/toolchain"`.

If you run opencode **on the host** instead of in the container, that path does not
exist. Either run the agent inside the `opencode` container, or override the shell
for host use.

## SSH from the agent to the toolchain fails

```bash
# from inside the opencode container
ssh -o LogLevel=DEBUG toolchain true
```

Check:

- The toolchain container is up: `docker compose ps`.
- The key pair exists: `~/AI/ssh/id_ed25519{,.pub}`.
- The entrypoint logged `SSH public key installed.` (`docker compose logs toolchain`).
- Rebuild the toolchain after changing `entrypoint.sh`:
  `docker compose up -d --build toolchain`.

`StrictHostKeyChecking no` + `UserKnownHostsFile /dev/null` mean host-key changes
after recreation are expected and harmless.

## No `/dev/ttyUSB*` / `/dev/ttyACM*` in the toolchain

```bash
docker exec esp-toolchain ls -l /dev/ttyUSB* /dev/ttyACM*
```

If empty, verify the **host** sees the device:

```bash
ls -l /dev/ttyUSB* /dev/ttyACM*
ls /sys/class/tty | grep -E 'ttyUSB|ttyACM'
lsusb
```

- Nothing on the host → bad/charge-only cable, wrong port, or missing driver
  (`cp210x`, `ch341`, `cdc_acm`).
- Present on the host but not in the container → the watcher needs ~2 s; check
  `docker compose logs toolchain` for `Exposed /dev/…`, and confirm the
  `device_cgroup_rules` are present in `docker-compose.yml`.

## `Permission denied` opening the serial port

Nodes are created with `chmod 0666`, so the `toolchain` user can open them. If you
changed that, use `sudo` inside the toolchain container or restore the `chmod`.

## OTA fails (`boiler-controller-v4.local` not found)

Containers on the `espdev` bridge may not resolve mDNS `.local` names to LAN
devices. Use the device's **IP address** instead:

```bash
esphome run boiler_controller.yaml --device 192.168.178.xx
```

Also confirm the device is on the same LAN and the OTA password matches
`secrets.yaml`.

## Git push fails / authentication error

Git runs locally in the agent container and uses `GITHUB_TOKEN` from `~/AI/.env` via
the credential helper in `.gitconfig/.gitconfig`.

- Ensure `.env` defines `GITHUB_TOKEN` and the container was (re)started after
  editing it.
- Verify inside the agent: `docker exec opencode bash -lc 'git config --list; echo $GITHUB_TOKEN | head -c4'`.

## Container won't start / `no such file or directory` for a device

Only relevant if you switched to the `devices:` approach — the device must exist at
start. Prefer the `mknod` watcher ([[USB Serial Passthrough]]), which has no such
requirement.

## Stale build results

Force a clean build inside the toolchain:

```bash
esphome clean boiler_controller.yaml
esphome compile boiler_controller.yaml
```
