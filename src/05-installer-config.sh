#!/usr/bin/env bash
# Stage 5: Configure Calamares graphical installer
set -euo pipefail

BUILDDIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ROOTFS="$BUILDDIR/rootfs"
CALAMARES_CFG="$ROOTFS/etc/calamares"

echo "==> Creating Calamares config directories ..."
mkdir -p "$CALAMARES_CFG/modules"
mkdir -p "$CALAMARES_CFG/branding/oilyos"

# ── settings.conf ───────────────────────────────────────────────────────────
cat > "$CALAMARES_CFG/settings.conf" << 'EOF'
---
modules-search: [ local, /usr/lib/x86_64-linux-gnu/calamares/modules ]

sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary
  - exec:
    - partition
    - mount
    - unpackfs
    - machineid
    - fstab
    - locale
    - keyboard
    - localecfg
    - users
    - removeuser
    - networkcfg
    - hwclock
    - services-systemd
    - initramfs
    - bootloader
    - umount
  - show:
    - finished

branding: oilyos
prompt-install: false
dont-chroot: false
EOF

# ── branding ─────────────────────────────────────────────────────────────────
cat > "$CALAMARES_CFG/branding/oilyos/branding.desc" << 'EOF'
---
componentName: oilyos

strings:
  productName:          "OilyOS"
  shortProductName:     "OilyOS"
  version:              "1.0"
  shortVersion:         "1.0"
  versionedName:        "OilyOS 1.0"
  shortVersionedName:   "OilyOS 1.0"
  bootloaderEntryName:  "OilyOS"
  productUrl:           ""
  supportUrl:           ""
  knownIssuesUrl:       ""
  releaseNotesUrl:      ""

images:
  productLogo:    "logo.png"
  productIcon:    "logo.png"
  productWelcome: "languages.png"

slideshow: "show.qml"
slideshowAPI: 1

style:
  sidebarBackground:  "#1a1a2e"
  sidebarText:        "#ffffff"
  sidebarTextSelect:  "#4fc3f7"
  sidebarTextHighlight: "#4fc3f7"
EOF

# Copy default branding images as placeholders
cp "$ROOTFS/usr/share/calamares/branding/default/logo.png"      "$CALAMARES_CFG/branding/oilyos/" 2>/dev/null || true
cp "$ROOTFS/usr/share/calamares/branding/default/languages.png" "$CALAMARES_CFG/branding/oilyos/" 2>/dev/null || true

# Minimal slideshow QML
cat > "$CALAMARES_CFG/branding/oilyos/show.qml" << 'EOF'
import QtQuick 2.0
import calamares.slideshow 1.0 as Slideshow

Slideshow.Presentation {
    id: presentation

    Slideshow.Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            text: "Installing OilyOS...\nPlease wait."
            font.pointSize: 18
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
        }
        Rectangle { anchors.fill: parent; color: "#1a1a2e"; z: -1 }
    }
}
EOF

# ── module configs ────────────────────────────────────────────────────────────

cat > "$CALAMARES_CFG/modules/welcome.conf" << 'EOF'
---
showSupportUrl:       false
showKnownIssuesUrl:   false
showReleaseNotesUrl:  false
requirements:
  requiredStorage:    8
  requiredRam:        1
  internetCheckUrl:   ""
  check:
    - storage
    - ram
    - root
  required:
    - storage
    - ram
    - root
EOF

cat > "$CALAMARES_CFG/modules/locale.conf" << 'EOF'
---
region:   "America"
zone:     "New_York"
EOF

cat > "$CALAMARES_CFG/modules/keyboard.conf" << 'EOF'
---
writeEtcDefaultKeyboard: true
EOF

cat > "$CALAMARES_CFG/modules/partition.conf" << 'EOF'
---
efiSystemPartition:      "/boot/efi"
efiSystemPartitionSize:  "300M"
efiSystemPartitionName:  "EFI System Partition"
userSwapChoices:
  - none
  - small
  - suspend
  - file
initialPartitioningChoice: none
initialSwapChoice:         none
EOF

cat > "$CALAMARES_CFG/modules/users.conf" << 'EOF'
---
defaultGroups:
  - sudo
  - audio
  - video
  - plugdev
  - netdev
autologinGroup:  autologin
sudoersGroup:    sudo
setRootPassword: true
doAutologin:     false
doReusePassword: true
passwordRequirements:
  minLength: -1
  maxLength: -1
  libpwquality:
    - minlen=0
    - dcredit=0
    - ucredit=0
    - ocredit=0
    - lcredit=0
EOF

cat > "$CALAMARES_CFG/modules/removeuser.conf" << 'EOF'
---
username: oily
EOF

cat > "$CALAMARES_CFG/modules/unpackfs.conf" << 'EOF'
---
unpack:
  - source:      /run/live/medium/live/filesystem.squashfs
    sourcefs:    squashfs
    destination: ""
EOF

cat > "$CALAMARES_CFG/modules/fstab.conf" << 'EOF'
---
mountOptions:
  default:    defaults
  btrfs:      defaults,compress=zstd:1
efiMountOptions: umask=0077
ssdExtraMountOptions:
  ext4:    discard
  btrfs:   discard,compress=zstd:1
EOF

cat > "$CALAMARES_CFG/modules/bootloader.conf" << 'EOF'
---
efiBootLoader:       "grub"
grubInstall:         "grub-install"
grubMkconfig:        "update-grub"
grubCfg:             "/boot/grub/grub.cfg"
grubProbe:           "grub-probe"
efiBootLoaderId:     "OilyOS"
installEFIFallback:  true
EOF

cat > "$CALAMARES_CFG/modules/services-systemd.conf" << 'EOF'
---
enable:
  - NetworkManager
  - lightdm
disable: []
EOF

cat > "$CALAMARES_CFG/modules/initramfs.conf" << 'EOF'
---
kernel: ""
EOF

cat > "$CALAMARES_CFG/modules/finished.conf" << 'EOF'
---
restartNowEnabled:  true
restartNowChecked:  true
restartNowCommand:  "reboot"
EOF

# ── polkit action (allow active-session users to run calamares as root) ───────
mkdir -p "$ROOTFS/usr/share/polkit-1/actions"
cat > "$ROOTFS/usr/share/polkit-1/actions/org.calamares.calamares.policy" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
  "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
<policyconfig>
  <action id="org.calamares.calamares">
    <description>Run the OilyOS installer</description>
    <message>Authentication is required to run the installer</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/sbin/calamares</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
EOF

# ── desktop shortcut ──────────────────────────────────────────────────────────
cat > "$ROOTFS/usr/share/applications/install-oilyos.desktop" << 'EOF'
[Desktop Entry]
Name=Install OilyOS
Comment=Install OilyOS to your disk
Exec=pkexec /usr/sbin/calamares
Icon=calamares
Type=Application
Categories=System;
Terminal=false
EOF

mkdir -p "$ROOTFS/home/oily/Desktop"
cp "$ROOTFS/usr/share/applications/install-oilyos.desktop" \
   "$ROOTFS/home/oily/Desktop/install-oilyos.desktop"
chmod +x "$ROOTFS/home/oily/Desktop/install-oilyos.desktop"

# Fix ownership — oily uid/gid inside the rootfs
OILY_UID=$(grep "^oily:" "$ROOTFS/etc/passwd" | cut -d: -f3)
OILY_GID=$(grep "^oily:" "$ROOTFS/etc/passwd" | cut -d: -f4)
chown -R "${OILY_UID}:${OILY_GID}" "$ROOTFS/home/oily/Desktop"

echo "==> Stage 5 complete. Calamares installer configured."
