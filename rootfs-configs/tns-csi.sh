# tns-csi rootfs profile — pre-install k3s and storage client tools for https://github.com/fenio/tns-csi.
# Sourced by build-rootfs.sh with ROOTFS_DIR set.

echo "  Installing storage client tools..."
chroot "$ROOTFS_DIR" apt-get update -qq
chroot "$ROOTFS_DIR" apt-get install -y -qq \
    nvme-cli \
    open-iscsi \
    nfs-common \
    cifs-utils
chroot "$ROOTFS_DIR" apt-get clean

echo "  Pre-installing k3s..."
K3S_VERSION="${K3S_VERSION:-}"
INSTALL_ARGS="INSTALL_K3S_SKIP_START=true INSTALL_K3S_SKIP_ENABLE=true"
if [ -n "$K3S_VERSION" ]; then
    INSTALL_ARGS="$INSTALL_ARGS INSTALL_K3S_VERSION=$K3S_VERSION"
fi

# Download k3s install script and binary into the rootfs
curl -sfL https://get.k3s.io -o "${ROOTFS_DIR}/tmp/k3s-install.sh"
chmod +x "${ROOTFS_DIR}/tmp/k3s-install.sh"

# Run the installer inside chroot — skip start/enable since there's no systemd running
chroot "$ROOTFS_DIR" /bin/bash -c \
    "$INSTALL_ARGS /tmp/k3s-install.sh"
rm -f "${ROOTFS_DIR}/tmp/k3s-install.sh"

echo "  k3s binary installed at:"
chroot "$ROOTFS_DIR" ls -lh /usr/local/bin/k3s
