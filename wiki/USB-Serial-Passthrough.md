# USB Serial Passthrough

The toolchain container needs access to the ESP32's USB serial port for flashing,
but the device name is not stable (`ttyUSB0` → `ttyUSB1` → `ttyACM0` …) and we do
**not** want to mount all of `/dev`.

## The approach: create the nodes ourselves

`toolchain/entrypoint.sh` runs a small watcher that mirrors the host's serial ports
into the container's `/dev`:

```bash
create_serial_nodes() {
    local sysdev name mm
    for sysdev in /sys/class/tty/ttyUSB* /sys/class/tty/ttyACM*; do
        [ -e "$sysdev/dev" ] || continue
        name="${sysdev##*/}"
        [ -e "/dev/$name" ] && continue
        mm="$(cat "$sysdev/dev")"
        mknod "/dev/$name" c "${mm%%:*}" "${mm##*:}"
        chmod 0666 "/dev/$name"
        echo "Exposed /dev/$name (major:minor $mm)"
    done
    # Drop stale nodes for devices that have been unplugged
    for name in /dev/ttyUSB* /dev/ttyACM*; do
        [ -e "$name" ] || continue
        [ -e "/sys/class/tty/${name##*/}" ] || rm -f "$name"
    done
}

create_serial_nodes
( while true; do create_serial_nodes; sleep 2; done ) &
```

## Why this works

- **sysfs is not namespaced.** `/sys/class/tty` inside the container lists the
  *host's* serial ports even though `/dev` is the container's own tmpfs. So the
  watcher can discover real devices (and their major:minor from `.../dev`).
- **The cgroup rules already permit access.** `docker-compose.yml` sets:

  ```yaml
  device_cgroup_rules:
    - 'c 188:* rmw'   # ttyUSB*
    - 'c 166:* rmw'   # ttyACM*
  ```

  Only the `/dev` node was missing — `mknod` supplies it.
- **No all-of-`/dev` mount.** Only `ttyUSB*` / `ttyACM*` nodes are created.
- **Hotplug-safe.** The 2-second loop picks up newly plugged devices and removes
  nodes for devices that disappear.

## Verify

With a board plugged in:

```bash
docker exec esp-toolchain ls -l /dev/ttyUSB* /dev/ttyACM*
# -> crw-rw-rw- 1 root root 166, 0 … /dev/ttyACM0
```

If nothing appears, check the **host** first:

```bash
ls -l /dev/ttyUSB* /dev/ttyACM*
ls /sys/class/tty | grep -E 'ttyUSB|ttyACM'
lsusb
```

No output on the host means the device/cable/driver is the problem, not the
container. Try a known-good data cable and a different port.

## Alternative: stable udev symlink

If you prefer a Docker-native `devices:` mapping, create a stable symlink on the
host and pass it in `docker-compose.yml`:

```bash
# /etc/udev/rules.d/99-esphome.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", SYMLINK+="esp32"   # ESP32-C3 USB-JTAG
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", SYMLINK+="esp32"   # CP210x
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", SYMLINK+="esp32"   # CH340
```

```bash
sudo udevadm control --reload && sudo udevadm trigger
```

```yaml
# docker-compose.yml (toolchain service)
devices:
  - "/dev/esp32:/dev/esp32"
```

Docker resolves the symlink and creates the node under the symlink's name.
**Trade-offs:** the device must be present when the container starts, and it does
not survive unplug/replug. The `mknod` watcher avoids both, so it is the preferred
method here.
