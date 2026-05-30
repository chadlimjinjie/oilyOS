#!/usr/bin/env bash
# Stage 1: Bootstrap minimal Debian bookworm into rootfs/
set -euo pipefail

BUILDDIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ROOTFS="$BUILDDIR/rootfs"

echo "==> Bootstrapping Debian bookworm into $ROOTFS ..."
debootstrap \
  --arch=amd64 \
  --variant=minbase \
  --include=systemd,systemd-sysv,locales,ca-certificates,apt-utils,dialog,sudo \
  bookworm \
  "$ROOTFS" \
  http://deb.debian.org/debian

echo "==> Bootstrap complete."
du -sh "$ROOTFS"
