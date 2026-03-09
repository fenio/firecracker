#!/bin/bash
# Build a Linux kernel (vmlinux) for Firecracker with extended config.
#
# Usage:
#   ./scripts/build-kernel.sh
#   KERNEL_VERSION=6.12.6 ./scripts/build-kernel.sh
#
# Output: dist/vmlinux

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KERNEL_VERSION="${KERNEL_VERSION:-6.12.76}"
KERNEL_MAJOR="${KERNEL_VERSION%%.*}"
FIRECRACKER_VERSION="${FIRECRACKER_VERSION:-v1.15.0}"
FIRECRACKER_CONFIG_URL="${FIRECRACKER_CONFIG_URL:-https://raw.githubusercontent.com/firecracker-microvm/firecracker/${FIRECRACKER_VERSION}/resources/guest_configs/microvm-kernel-ci-x86_64-6.1.config}"

WORKING_DIR="${PROJECT_ROOT}/working"
DIST_DIR="${PROJECT_ROOT}/dist"

echo "=== Building Firecracker kernel ==="
echo "  Kernel:  ${KERNEL_VERSION}"
echo "  Config:  ${FIRECRACKER_CONFIG_URL}"
echo ""

mkdir -p "$WORKING_DIR" "$DIST_DIR"

# ── Download kernel source ────────────────────────────────────
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/${KERNEL_TAR}"

if [ ! -f "${WORKING_DIR}/${KERNEL_TAR}" ]; then
    echo "Downloading kernel source..."
    curl -fSL -o "${WORKING_DIR}/${KERNEL_TAR}" "$KERNEL_URL"
else
    echo "Using cached kernel source"
fi

# ── Extract ───────────────────────────────────────────────────
KERNEL_SRC="${WORKING_DIR}/linux-${KERNEL_VERSION}"
if [ ! -d "$KERNEL_SRC" ]; then
    echo "Extracting kernel source..."
    tar -xf "${WORKING_DIR}/${KERNEL_TAR}" -C "$WORKING_DIR"
fi

# ── Download and merge config ─────────────────────────────────
echo "Downloading Firecracker base config..."
curl -fSL -o "${KERNEL_SRC}/.config" "$FIRECRACKER_CONFIG_URL"

EXTRA_CONFIG="${PROJECT_ROOT}/kernel-config-extra"
if [ -f "$EXTRA_CONFIG" ]; then
    ADDED=$(grep -cE '^CONFIG_' "$EXTRA_CONFIG" || true)
    if [ "$ADDED" -gt 0 ]; then
        echo "Merging extra config options..."
        echo "" >> "${KERNEL_SRC}/.config"
        echo "# === Extra options from kernel-config-extra ===" >> "${KERNEL_SRC}/.config"
        grep -E '^CONFIG_' "$EXTRA_CONFIG" >> "${KERNEL_SRC}/.config"
        echo "  Added ${ADDED} extra config options"
    else
        echo "No extra config options to merge"
    fi
fi

echo "Running olddefconfig..."
make -C "$KERNEL_SRC" olddefconfig

# ── Build ─────────────────────────────────────────────────────
echo ""
echo "Building vmlinux (this will take a while)..."
make -C "$KERNEL_SRC" -j"$(nproc)" vmlinux

# ── Collect output ────────────────────────────────────────────
cp "${KERNEL_SRC}/vmlinux" "${DIST_DIR}/vmlinux"

echo ""
echo "=== Kernel build complete ==="
echo "  Output: ${DIST_DIR}/vmlinux"
ls -lh "${DIST_DIR}/vmlinux"
