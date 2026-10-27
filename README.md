# Wonder's Arch Linux Rice

Personal Arch Linux configuration and dotfiles.

## Components

- Hyprland and Lua configuration modules
- Quickshell
- Walker and Elephant
- Fastfetch
- Hyprlock
- Bash startup configuration
- Custom scripts and terminal utilities
- Wallpapers and cursor theme

## Notes

This repository contains configuration backups for my personal setup.
Review paths and dependencies before restoring on another machine.

## Restore after a clean Arch installation

Clone this repository, then run the script as your normal user (not as root):

```bash
git clone https://github.com/wonderdoublerr-commits/my-arch-linux-rice.git ~/dotfiles
cd ~/dotfiles
./restore.sh
```

The script installs the saved pacman, AUR and Flatpak applications; restores
dotfiles, scripts, wallpapers and the cursor; and enables the saved services.
It backs up files that it replaces under `~/.local/state/dotfiles-backups/`.

The package snapshot is specific to this computer and includes its graphics
drivers and AMD microcode. Review it before restoring onto different hardware.

This is a system-setup backup, not a backup of personal data. In particular,
`bin/auralis` and `bin/minify` expect separate projects in `~/Downloads`, and
the optional manually downloaded JDK is not included. Back up those projects,
documents, browser profiles, game saves and secrets separately.
