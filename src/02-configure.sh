#!/usr/bin/env bash
# Stage 2: Configure base system and install XFCE inside chroot
set -euo pipefail

BUILDDIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ROOTFS="$BUILDDIR/rootfs"

# Mount kernel filesystems
mount --bind /dev     "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
mount -t proc  proc  "$ROOTFS/proc"
mount -t sysfs sysfs "$ROOTFS/sys"

cleanup() {
  echo "==> Unmounting kernel filesystems ..."
  umount -lf "$ROOTFS/dev/pts" 2>/dev/null || true
  umount -lf "$ROOTFS/dev"     2>/dev/null || true
  umount -lf "$ROOTFS/proc"    2>/dev/null || true
  umount -lf "$ROOTFS/sys"     2>/dev/null || true
}
trap cleanup EXIT

# Write the chroot script
cat > "$ROOTFS/tmp/inside-chroot.sh" << 'CHROOT'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- Basic config ---
echo "oilysOS" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   oilyOS
EOF

# Locale & timezone
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# APT sources
cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free
deb http://deb.debian.org/debian bookworm-updates main contrib non-free
EOF

apt-get update -qq

# --- Fix broken packages from bootstrap (polkitd needs logind) ---
echo "==> Fixing bootstrap package state ..."
apt-get install -y --no-install-recommends libpam-systemd
apt-get -f install -y

# --- Kernel ---
echo "==> Installing kernel ..."
apt-get install -y linux-image-amd64

# --- Desktop environment ---
echo "==> Installing XFCE desktop ..."
apt-get install -y --no-install-recommends \
  xorg xserver-xorg-video-all xserver-xorg-input-all \
  xfce4 xfce4-terminal xfce4-whiskermenu-plugin \
  lightdm lightdm-gtk-greeter \
  thunar thunar-volman \
  xfce4-power-manager xfce4-notifyd xfce4-screenshooter \
  mousepad ristretto \
  gvfs gvfs-backends \
  network-manager-gnome \
  pulseaudio pavucontrol \
  fonts-dejavu fonts-liberation \
  firefox-esr \
  xdg-utils

# --- Live system tools ---
echo "==> Installing live system support ..."
apt-get install -y --no-install-recommends live-boot live-config

# --- Create default user ---
echo "==> Creating default user 'oily' ..."
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev oily
echo "oily:oily" | chpasswd
echo "root:root" | chpasswd

# Enable autologin via LightDM
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << EOF
[Seat:*]
autologin-user=oily
autologin-user-timeout=0
EOF

# Enable services
systemctl enable lightdm NetworkManager

# Clean up apt cache to save space
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "==> Chroot configuration complete."
CHROOT

chmod +x "$ROOTFS/tmp/inside-chroot.sh"
echo "==> Entering chroot ..."
chroot "$ROOTFS" /tmp/inside-chroot.sh
rm -f "$ROOTFS/tmp/inside-chroot.sh"
echo "==> Stage 2 complete."
