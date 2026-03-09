# linux-firecracker

Builds a Linux kernel and Ubuntu 24.04 rootfs for [Firecracker](https://github.com/firecracker-microvm/firecracker) microVMs.

## Kernel profiles

| Profile | Description | Use case |
|---------|-------------|----------|
| `minimal` | PCI VirtIO transport only | Boot a VM and run shell commands |
| `base` | Networking support | VMs that need network access |
| [`tns-csi`](https://github.com/fenio/tns-csi) | Networking + k3s + storage protocols | CSI driver testing with NVMe-oF, iSCSI, NFS, SMB |

All profiles use PCI VirtIO transport (`--enable-pci`).

## Rootfs profiles

| Profile | Description |
|---------|-------------|
| `base` | Ubuntu 24.04 with systemd, SSH, networking |
| [`tns-csi`](https://github.com/fenio/tns-csi) | Base + pre-installed k3s, nvme-cli, open-iscsi, nfs-common, cifs-utils |

## Release artifacts

Each [release](https://github.com/fenio/linux-firecracker/releases) includes:

- `vmlinux-minimal` / `vmlinux-base` / `vmlinux-tns-csi` — kernel variants
- `rootfs-base.ext4.zst` / `rootfs-tns-csi.ext4.zst` — rootfs variants (zstd-compressed)
- `id_rsa` / `id_rsa.pub` — SSH keypair for VM access
- `firecracker` — Firecracker binary

## Building locally

```bash
# Build kernel (default: base profile)
./scripts/build-kernel.sh

# Build a specific kernel profile
KERNEL_PROFILE=tns-csi ./scripts/build-kernel.sh

# Build rootfs (default: base profile, requires root)
sudo ./scripts/build-rootfs.sh

# Build a specific rootfs profile
sudo ROOTFS_PROFILE=tns-csi ./scripts/build-rootfs.sh
```

### Requirements

- Build essentials: `build-essential bc flex bison libelf-dev libssl-dev`
- Rootfs: `debootstrap e2fsprogs`

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `KERNEL_PROFILE` | `base` | Kernel profile (`minimal`, `base`, `tns-csi`) |
| `KERNEL_VERSION` | `6.12.76` | Linux kernel version |
| `FIRECRACKER_VERSION` | `v1.15.0` | Firecracker version (for base config URL) |
| `ROOTFS_PROFILE` | `base` | Rootfs profile (`base`, `tns-csi`) |
| `ROOTFS_SIZE` | `2G` | Rootfs image size |

## Used by

- [setup-firecracker](https://github.com/fenio/setup-firecracker) — GitHub Action to run commands in a Firecracker VM
