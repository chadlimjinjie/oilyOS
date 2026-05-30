# OilyOS

A custom Linux distribution built on Debian 12 (Bookworm) with the XFCE desktop. Produces a bootable hybrid ISO supporting both BIOS (isolinux) and UEFI (GRUB EFI) boot, with a Calamares graphical installer for installation to disk.

## Requirements

Build must be run as root on a Debian/Ubuntu host. Install the required packages first:

```bash
sudo apt-get install debootstrap isolinux syslinux-common mtools xorriso squashfs-tools grub-efi-amd64-bin
```

## Build

Run each stage from the repo root in order:

```bash
sudo bash src/01-bootstrap.sh       # Debootstrap Debian bookworm into build/rootfs/
sudo bash src/02-configure.sh       # Install kernel, XFCE, LightDM, Calamares (chroot)
sudo bash src/03-branding.sh        # Inject branding, GRUB config, XFCE defaults
sudo bash src/05-installer-config.sh  # Write Calamares config into rootfs
sudo bash src/04-build-iso.sh       # Pack squashfs + build bootable ISO
```

Output: `build/oilyos-1.0.iso`

### Rebuilding after script changes

Stage 4 only packs whatever is currently in `build/rootfs` — it does not re-apply earlier stages. After modifying any stage script, re-run that stage before running stage 4:

```bash
# Example: after editing stage 2 or 5
sudo bash src/02-configure.sh
sudo bash src/05-installer-config.sh
sudo bash src/04-build-iso.sh
```

To rebuild from scratch, delete `build/rootfs` and run all stages again:

```bash
sudo rm -rf build/
sudo bash src/01-bootstrap.sh
# ... continue with remaining stages
```

## Boot & Install

Boot the ISO in a VM or write it to a USB drive:

```bash
sudo dd if=build/oilyos-1.0.iso of=/dev/sdX bs=4M status=progress && sync
```

The live session autologins as `oily` and launches the Calamares installer directly. Follow the on-screen prompts to install to disk. The live `oily` user is removed during installation.

## Default Credentials

| Account | Username | Password |
|---------|----------|----------|
| Live user | `oily` | `oily` |
| Root | `root` | `root` |

These apply only to the live session. Calamares prompts for new credentials during installation.

## Project Structure

```
src/
  01-bootstrap.sh        # Debootstrap minimal Debian base
  02-configure.sh        # Chroot: packages, kernel, XFCE, LightDM, Calamares
  03-branding.sh         # OS release, GRUB config, XFCE theme defaults
  04-build-iso.sh        # squashfs + isolinux + GRUB EFI → ISO
  05-installer-config.sh # Calamares settings, modules, branding, xsession

build/                   # Generated artifacts (not committed)
  rootfs/                # Live filesystem root
  iso/                   # ISO staging tree
  oilyos-1.0.iso         # Final bootable image
```

## Installer Modules

Calamares runs the following modules in order during installation:

`partition → mount → unpackfs → machineid → fstab → locale → keyboard → localecfg → users → removeuser → networkcfg → hwclock → services-systemd → initramfs → bootloader → umount`
