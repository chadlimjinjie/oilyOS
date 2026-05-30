# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

OilyOS is a custom Linux distribution built on Debian 12 (bookworm) with the XFCE desktop. It produces a bootable hybrid ISO that supports both BIOS (isolinux) and UEFI (GRUB EFI) boot, and includes a Calamares graphical installer for installing to disk.

All build scripts live in `build/` and must be run as root (they use `debootstrap`, `chroot`, `mount`, `mksquashfs`, `xorriso`, etc.).

## Build pipeline

The build is split into five sequential stages. Run each from the repo root as root:

```bash
sudo bash build/01-bootstrap.sh      # debootstrap Debian bookworm into build/rootfs/
sudo bash build/02-configure.sh      # chroot: install kernel, XFCE, LightDM, live-boot
sudo bash build/03-branding.sh       # inject /etc/os-release, GRUB config, XFCE defaults
sudo bash build/04-build-iso.sh      # squashfs + isolinux + GRUB EFI → build/oilyos-1.0.iso
sudo bash build/05-installer-config.sh  # write Calamares config into rootfs (run before stage 4 if adding installer)
```

`build/rootfs/` is the live filesystem root — all OS customisation happens there (directly or via chroot).  
`build/iso/` is the ISO staging tree assembled by stage 4.  
`build/oilyos-1.0.iso` is the final output.

## Architecture

| Concern | Where it lives |
|---|---|
| Base OS + packages | `02-configure.sh` (chroot script embedded via heredoc) |
| Branding & XFCE defaults | `03-branding.sh` → `rootfs/etc/os-release`, `rootfs/usr/share/oilyos/`, `rootfs/home/oily/.config/autostart/` |
| Boot loaders | `04-build-iso.sh` — isolinux for BIOS, `grub-mkstandalone` EFI image for UEFI |
| Graphical installer | `05-installer-config.sh` → `rootfs/etc/calamares/` (settings.conf, module configs, branding) |
| Live session user | username `oily`, password `oily`; autologin via LightDM |

## Key host dependencies

Stage 4 requires these packages on the build host:

```
debootstrap isolinux syslinux-common mtools xorriso squashfs-tools grub-efi-amd64-bin
```

## Default credentials

- Live user: `oily` / `oily`
- Root: `root` / `root`

These exist only in the live session; Calamares (`05`) removes the `oily` user and prompts for new credentials on install.

## Calamares installer sequence

Stage 5 wires up Calamares with these exec modules (in order):  
`partition → mount → unpackfs → machineid → fstab → locale → keyboard → localecfg → users → removeuser → networkcfg → hwclock → services-systemd → initramfs → bootloader → umount`

The squashfs source path expected at runtime is `/run/live/medium/live/filesystem.squashfs` (standard `live-boot` mount point).
