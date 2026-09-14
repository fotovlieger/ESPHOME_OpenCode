# Workflow

Day-to-day use of the environment, using the `BoilerController` ESPHome project as
the example.

> [!NOTE]
> `BoilerController` is only an example. Substitute your own project directory and
> YAML file names — the commands and routing are identical for any ESPHome project.

## 1. Start / enter the environment

```bash
cd ~/AI
docker compose up -d --build      # first time or after changing a Dockerfile
docker attach opencode            # or: docker exec -it opencode bash
```

## 2. Edit

Just talk to opencode. It edits files under
`/workspace/BoilerController/` directly (e.g. `boiler_controller.yaml`, the custom
component in `external/my_component/`). No copying between containers is needed.

## 3. Build

Ask the agent, or run:

```bash
esphome compile boiler_controller.yaml
```

This executes in `esp-toolchain`. Output lands in
`/workspace/BoilerController/.esphome/build/boiler-controller-v4/`, e.g.
`firmware.ota.bin` and `firmware.factory.bin`.

## 4. Flash

### Over the air (OTA — the default)

The YAML declares an OTA platform:

```yaml
ota:
  - platform: esphome
    password: !secret ota_password
```

So after the first flash, update wirelessly:

```bash
esphome run boiler_controller.yaml --device boiler-controller-v4.local
# or just upload the already-built image:
esphome upload boiler_controller.yaml --device boiler-controller-v4.local
```

### Over USB serial

For a first flash or when WiFi is unavailable (requires the serial node to be
exposed — see [[USB Serial Passthrough]]):

```bash
esphome run boiler_controller.yaml --device /dev/ttyACM0
```

## 5. Logs

```bash
esphome logs boiler_controller.yaml --device boiler-controller-v4.local
```

## 6. Version control

Git runs locally in the agent container, authenticated via `GITHUB_TOKEN`:

```bash
git add -A
git commit -m "…"
git push
```

`git` commands are routed locally by the wrapper ([[Command Routing]]), so pushes
work without any GitHub credentials in the toolchain.

## What is version-controlled

`.esphome/` (build cache), `*.bin` firmware, `secrets.yaml`, and `fonts/` are
gitignored in the project — only source (YAML, external components, tests) is
tracked.

## Cheat sheet

| Task | Command | Where |
|------|---------|-------|
| Compile | `esphome compile boiler_controller.yaml` | toolchain |
| Flash OTA | `esphome run … --device boiler-controller-v4.local` | toolchain |
| Flash USB | `esphome run … --device /dev/ttyACM0` | toolchain |
| Logs | `esphome logs … --device …` | toolchain |
| Commit / push | `git …` | opencode |
| Serial devices | `ls -l /dev/ttyUSB* /dev/ttyACM*` | toolchain |
