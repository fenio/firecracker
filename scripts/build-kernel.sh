#!/bin/bash
# Build a Linux kernel (vmlinux) for Firecracker with a given profile.
#
# Usage:
#   ./scripts/build-kernel.sh                        # builds "base" profile
#   KERNEL_PROFILE=minimal ./scripts/build-kernel.sh
#   KERNEL_PROFILE=tns-csi KERNEL_VERSION=6.12.6 ./scripts/build-kernel.sh
#
# Profiles: minimal, base, tns-csi  (see kernel-configs/)
#
# Output: dist/vmlinux-<profile>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KERNEL_PROFILE="${KERNEL_PROFILE:-base}"
KERNEL_VERSION="${KERNEL_VERSION:-6.12.76}"
KERNEL_MAJOR="${KERNEL_VERSION%%.*}"
FIRECRACKER_VERSION="${FIRECRACKER_VERSION:-v1.15.0}"
FIRECRACKER_CONFIG_URL="${FIRECRACKER_CONFIG_URL:-https://raw.githubusercontent.com/firecracker-microvm/firecracker/${FIRECRACKER_VERSION}/resources/guest_configs/microvm-kernel-ci-x86_64-6.1.config}"

WORKING_DIR="${PROJECT_ROOT}/working"
DIST_DIR="${PROJECT_ROOT}/dist"

PROFILE_CONFIG="${PROJECT_ROOT}/kernel-configs/${KERNEL_PROFILE}.config"
if [ ! -f "$PROFILE_CONFIG" ]; then
    echo "ERROR: Unknown profile '${KERNEL_PROFILE}'"
    echo "Available profiles:"
    ls -1 "${PROJECT_ROOT}/kernel-configs/"*.config 2>/dev/null | xargs -I{} basename {} .config
    exit 1
fi

echo "=== Building Firecracker kernel ==="
echo "  Profile: ${KERNEL_PROFILE}"
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

ADDED=$(grep -cE '^CONFIG_' "$PROFILE_CONFIG" || true)
if [ "$ADDED" -gt 0 ]; then
    echo "Merging ${KERNEL_PROFILE} profile config..."
    echo "" >> "${KERNEL_SRC}/.config"
    echo "# === Profile: ${KERNEL_PROFILE} ===" >> "${KERNEL_SRC}/.config"
    grep -E '^CONFIG_' "$PROFILE_CONFIG" >> "${KERNEL_SRC}/.config"
    echo "  Added ${ADDED} config options"
fi

echo "Running olddefconfig..."
make -C "$KERNEL_SRC" olddefconfig

# ── Build ─────────────────────────────────────────────────────
echo ""
echo "Building vmlinux (this will take a while)..."
make -C "$KERNEL_SRC" -j"$(nproc)" vmlinux

# ── Collect output ────────────────────────────────────────────
OUTPUT="${DIST_DIR}/vmlinux-${KERNEL_PROFILE}"
cp "${KERNEL_SRC}/vmlinux" "$OUTPUT"

echo ""
echo "=== Kernel build complete ==="
echo "  Output: ${OUTPUT}"
ls -lh "$OUTPUT"
