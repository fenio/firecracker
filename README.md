# linux-firecracker

Builds a Linux kernel and Ubuntu 24.04 rootfs for [Firecracker](https://github.com/firecracker-microvm/firecracker) microVMs.

## Kernel profiles

Three kernel profiles are available, each building on Firecracker's upstream microvm config:

| Profile | Description | Use case |
|---------|-------------|----------|
| `minimal` | PCI VirtIO transport only | Boot a VM and run shell commands |
| `base` | Networking support | VMs that need network access |
| `tns-csi` | Networking + k3s + storage protocols | CSI driver testing with NVMe-oF, iSCSI, NFS, SMB |

All profiles use PCI VirtIO transport (`--enable-pci`).

## Release artifacts

Each [release](https://github.com/fenio/linux-firecracker/releases) includes:

- `vmlinux-minimal` — minimal kernel
- `vmlinux-base` — base kernel with networking
- `vmlinux-tns-csi` — full kernel for CSI testing
- `rootfs.ext4.zst` — zstd-compressed Ubuntu 24.04 rootfs
- `id_rsa` / `id_rsa.pub` — SSH keypair for VM access
- `firecracker` — Firecracker binary

## Building locally

```bash
# Build kernel (default: base profile)
./scripts/build-kernel.sh

# Build a specific profile
KERNEL_PROFILE=tns-csi ./scripts/build-kernel.sh

# Build rootfs (requires root)
sudo ./scripts/build-rootfs.sh
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
| `ROOTFS_SIZE` | `2G` | Rootfs image size |

## Used by

- [linux-firecracker-action](https://github.com/fenio/linux-firecracker-action) — GitHub Action to run commands in a Firecracker VM
