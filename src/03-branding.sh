#!/usr/bin/env bash
# Stage 3: Apply OilyOS branding
set -euo pipefail

BUILDDIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ROOTFS="$BUILDDIR/rootfs"

echo "==> Applying OilyOS branding ..."

# OS release info
cat > "$ROOTFS/etc/os-release" << 'EOF'
PRETTY_NAME="OilyOS 1.0"
NAME="OilyOS"
VERSION_ID="1.0"
VERSION="1.0 (Slick)"
ID=oilysOS
ID_LIKE=debian
HOME_URL="https://github.com/your-username/oilyOS"
SUPPORT_URL="https://github.com/your-username/oilyOS/issues"
BUG_REPORT_URL="https://github.com/your-username/oilyOS/issues"
LOGO=oilysOS-logo
EOF

cat > "$ROOTFS/etc/issue" << 'EOF'
OilyOS 1.0 \n \l
EOF

cat > "$ROOTFS/etc/issue.net" << 'EOF'
OilyOS 1.0
EOF

# XFCE default wallpaper (solid dark teal — no external download needed)
mkdir -p "$ROOTFS/usr/share/oilyos"
cat > "$ROOTFS/usr/share/oilyos/set-defaults.sh" << 'DEFAULTS'
#!/usr/bin/env bash
# Set OilyOS XFCE defaults for a user session (run once on first login)
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image \
  -s /usr/share/backgrounds/xfce/xfce-verticals.png 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/theme -s Greybird 2>/dev/null || true
xfconf-query -c xsettings -p /Net/ThemeName -s Greybird 2>/dev/null || true
DEFAULTS
chmod +x "$ROOTFS/usr/share/oilyos/set-defaults.sh"

# Set default XFCE session for the oily user
mkdir -p "$ROOTFS/home/oily/.config/autostart"
cat > "$ROOTFS/home/oily/.config/autostart/oilyos-defaults.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=OilyOS Defaults
Exec=/usr/share/oilyos/set-defaults.sh
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

# GRUB theme branding
mkdir -p "$ROOTFS/boot/grub"
cat > "$ROOTFS/boot/grub/grub.cfg" << 'EOF'
set default=0
set timeout=5

menuentry "OilyOS 1.0 Live" {
    linux  /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}

menuentry "OilyOS 1.0 (safe mode)" {
    linux  /live/vmlinuz boot=live nomodeset
    initrd /live/initrd
}
EOF

chown -R 1000:1000 "$ROOTFS/home/oily"

echo "==> Branding applied."
