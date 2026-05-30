#!/usr/bin/env bash
# Stage 4: Pack rootfs into squashfs and build bootable ISO (BIOS via isolinux + UEFI via GRUB)
set -euo pipefail

BUILDDIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ROOTFS="$BUILDDIR/rootfs"
ISODIR="$BUILDDIR/iso"
OUTPUT="$BUILDDIR/oilyos-1.0.iso"

echo "==> Copying kernel and initrd ..."
mkdir -p "$ISODIR/live"
cp "$ROOTFS/boot"/vmlinuz-*    "$ISODIR/live/vmlinuz"
cp "$ROOTFS/boot"/initrd.img-* "$ISODIR/live/initrd"

echo "==> Packing rootfs into squashfs (this takes a few minutes) ..."
mksquashfs "$ROOTFS" "$ISODIR/live/filesystem.squashfs" \
  -comp xz -e boot -noappend

echo "==> Setting up isolinux (BIOS boot) ..."
mkdir -p "$ISODIR/isolinux"
cp /usr/lib/ISOLINUX/isolinux.bin     "$ISODIR/isolinux/"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32  "$ISODIR/isolinux/"
cp /usr/lib/syslinux/modules/bios/menu.c32     "$ISODIR/isolinux/"
cp /usr/lib/syslinux/modules/bios/libutil.c32  "$ISODIR/isolinux/"

cat > "$ISODIR/isolinux/isolinux.cfg" << 'EOF'
UI menu.c32
PROMPT 0
TIMEOUT 100
DEFAULT live

LABEL live
  MENU LABEL OilyOS 1.0 Live
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live

LABEL safe
  MENU LABEL OilyOS 1.0 (safe mode)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live nomodeset
EOF

echo "==> Setting up GRUB EFI boot ..."
mkdir -p "$ISODIR/EFI/BOOT"
cat > /tmp/grub-efi.cfg << 'EOF'
set default=0
set timeout=10

insmod all_video
insmod font
if loadfont unicode ; then
  insmod gfxterm
  set gfxmode=auto
  terminal_output gfxterm
else
  terminal_output console
fi

menuentry "OilyOS 1.0 Live" {
    linux  /live/vmlinuz boot=live
    initrd /live/initrd
}

menuentry "OilyOS 1.0 (safe mode)" {
    linux  /live/vmlinuz boot=live nomodeset
    initrd /live/initrd
}
EOF

grub-mkstandalone \
  --format=x86_64-efi \
  --output="$ISODIR/EFI/BOOT/BOOTX64.EFI" \
  --locales="" \
  --fonts="unicode" \
  "boot/grub/grub.cfg=/tmp/grub-efi.cfg"

echo "==> Creating EFI partition image ..."
dd if=/dev/zero of="$ISODIR/boot/efi.img" bs=1M count=10 status=none
mkdosfs -F 12 "$ISODIR/boot/efi.img" > /dev/null
mmd  -i "$ISODIR/boot/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "$ISODIR/boot/efi.img" "$ISODIR/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/

echo "==> Building hybrid ISO with xorriso ..."
xorriso -as mkisofs \
  -iso-level 3 \
  -volid "OILYOS_1_0" \
  -full-iso9660-filenames \
  -J -R \
  -c isolinux/boot.cat \
  -b isolinux/isolinux.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/efi.img \
  -no-emul-boot \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -o "$OUTPUT" \
  "$ISODIR"

echo ""
echo "==> Done! ISO created at: $OUTPUT"
ls -lh "$OUTPUT"
