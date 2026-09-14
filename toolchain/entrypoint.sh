#!/bin/bash
set -e

echo "=== Starting ESP32 toolchain ==="

# SSH directories
mkdir -p /run/sshd
mkdir -p /home/toolchain/.ssh

# Install OpenCode public key
if [ -f /tmp/opencode_id_ed25519.pub ]; then
    cp /tmp/opencode_id_ed25519.pub /home/toolchain/.ssh/authorized_keys

    chown -R toolchain:toolchain /home/toolchain/.ssh
    chmod 700 /home/toolchain/.ssh
    chmod 600 /home/toolchain/.ssh/authorized_keys

    echo "SSH public key installed."
else
    echo "WARNING: OpenCode SSH public key not found."
fi

# SSH configuration: key authentication only
sed -i \
    -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' \
    /etc/ssh/sshd_config

# Start SSH server
/usr/sbin/sshd

# Expose USB serial adapters (ttyUSB*/ttyACM*) without mounting all of /dev.
# sysfs is not namespaced, so /sys/class/tty lists the host's serial ports even
# though /dev does not. docker-compose's device_cgroup_rules already allow
# major 188 (ttyUSB) and 166 (ttyACM), so we just mknod the matching nodes and
# keep watching for hotplug / changing names (ttyUSB0 -> ttyUSB1, ttyACM0, ...).
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

echo
echo "=== ESP32 TOOLCHAIN ==="
esphome version || true
echo "Python:"
python3 --version

echo
echo "USB devices:"
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true

echo
echo "Ready."

# Keep container running
exec tail -f /dev/null
