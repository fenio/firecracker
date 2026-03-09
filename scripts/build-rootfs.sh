#!/bin/bash
# Build an Ubuntu 24.04 rootfs for Firecracker.
#
# Usage:
#   sudo ./scripts/build-rootfs.sh
#
# Output: dist/rootfs.ext4, dist/id_rsa, dist/id_rsa.pub
#
# Must be run as root (debootstrap requires it).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ROOTFS_SIZE="${ROOTFS_SIZE:-2G}"
DIST_DIR="${PROJECT_ROOT}/dist"
WORKING_DIR="${PROJECT_ROOT}/working"
ROOTFS_DIR="${WORKING_DIR}/rootfs"

echo "=== Building Ubuntu 24.04 rootfs for Firecracker ==="
echo "  Size: ${ROOTFS_SIZE}"
echo ""

mkdir -p "$DIST_DIR" "$WORKING_DIR"

# ── Generate SSH keypair ──────────────────────────────────────
if [ ! -f "${DIST_DIR}/id_rsa" ]; then
    echo "Generating SSH keypair..."
    ssh-keygen -t rsa -b 4096 -f "${DIST_DIR}/id_rsa" -N "" -q
fi

# ── Bootstrap rootfs ─────────────────────────────────────────
echo "Running debootstrap..."
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
debootstrap --include=systemd,systemd-sysv,openssh-server,iproute2,iptables,curl,ca-certificates,dbus,kmod,udev \
    noble "$ROOTFS_DIR" http://archive.ubuntu.com/ubuntu

# ── Configure networking ─────────────────────────────────────
echo "Configuring network..."

cat > "${ROOTFS_DIR}/etc/systemd/network/20-wired.network" <<'EOF'
[Match]
Name=en* eth*

[Network]
Address=172.16.0.2/24
Gateway=172.16.0.1
DNS=8.8.8.8
DNS=1.1.1.1
EOF

# Enable systemd-networkd
ln -sf /lib/systemd/system/systemd-networkd.service \
    "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
ln -sf /lib/systemd/system/systemd-resolved.service \
    "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/systemd-resolved.service"

# Set hostname
echo "firecracker" > "${ROOTFS_DIR}/etc/hostname"
cat > "${ROOTFS_DIR}/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 firecracker
::1 localhost
EOF

# DNS resolv.conf — use static file for early boot reliability
cat > "${ROOTFS_DIR}/etc/resolv.conf" <<'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

# ── Configure SSH ─────────────────────────────────────────────
echo "Configuring SSH..."

# Enable root login with key auth only
sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' "${ROOTFS_DIR}/etc/ssh/sshd_config"
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' "${ROOTFS_DIR}/etc/ssh/sshd_config"
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' "${ROOTFS_DIR}/etc/ssh/sshd_config"

# Install authorized keys
mkdir -p "${ROOTFS_DIR}/root/.ssh"
cp "${DIST_DIR}/id_rsa.pub" "${ROOTFS_DIR}/root/.ssh/authorized_keys"
chmod 700 "${ROOTFS_DIR}/root/.ssh"
chmod 600 "${ROOTFS_DIR}/root/.ssh/authorized_keys"

# Generate SSH host keys
chroot "$ROOTFS_DIR" ssh-keygen -A

# Enable SSH
ln -sf /lib/systemd/system/ssh.service \
    "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/ssh.service" 2>/dev/null || \
ln -sf /lib/systemd/system/sshd.service \
    "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/sshd.service" 2>/dev/null || true

# ── Configure systemd ────────────────────────────────────────
echo "Configuring systemd..."

# Set root password (empty - key auth only)
chroot "$ROOTFS_DIR" passwd -d root

# Auto-login on serial console for debugging
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/serial-getty@ttyS0.service.d"
cat > "${ROOTFS_DIR}/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 115200 linux
EOF

# Faster boot: reduce systemd timeouts
mkdir -p "${ROOTFS_DIR}/etc/systemd/system.conf.d"
cat > "${ROOTFS_DIR}/etc/systemd/system.conf.d/timeout.conf" <<'EOF'
[Manager]
DefaultTimeoutStartSec=15s
DefaultTimeoutStopSec=10s
EOF

# ── Create rootfs image ──────────────────────────────────────
echo "Creating ext4 image (${ROOTFS_SIZE})..."

ROOTFS_IMG="${DIST_DIR}/rootfs.ext4"
truncate -s "$ROOTFS_SIZE" "$ROOTFS_IMG"
mkfs.ext4 -F -d "$ROOTFS_DIR" "$ROOTFS_IMG"

echo ""
echo "=== Rootfs build complete ==="
echo "  Image:   ${ROOTFS_IMG}"
echo "  SSH key: ${DIST_DIR}/id_rsa"
ls -lh "${DIST_DIR}/rootfs.ext4" "${DIST_DIR}/id_rsa" "${DIST_DIR}/id_rsa.pub"
