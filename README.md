[![ShellCheck Strict Lint x11vnc-setup.sh](https://github.com/domomg/x11vnc-setup/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/domomg/x11vnc-setup/actions/workflows/shellcheck.yml)

# x11vnc-setup
A cross-distro Bash script to install and configure x11vnc as a systemd service that attaches to an existing X11 session, just like Windows Remote Desktop or macOS Screen Sharing do.

Unlike most VNC setups that spin up a separate virtual desktop, this script gives you **real-time access to your actual desktop session**, making it perfect for remote administration of your workstation.

---

## Key Features

- Works across multiple distros:  
  Ubuntu, Debian, Linux Mint, CentOS/RHEL/Rocky, Fedora, Arch Linux, Manjaro, openSUSE
- Secure password authentication (stored properly, never echoed)  
- Systemd integration: Runs in the background and survives reboots  
- Interactive setup: Guides you through user, port, password, and network binding configuration (bind to all interfaces or localhost for security)
- Hardened service: Systemd protections (`ProtectSystem`, `ProtectHome`, etc.)  
- Clean and validated: Handles dependencies, checks for common pitfalls  

---

## Supported Platforms

Tested and working on:  
- Debian-based: Ubuntu, Debian, Linux Mint
- RHEL-based: CentOS, RHEL, Rocky, AlmaLinux
- Fedora
- Arch Linux/Manjaro
- openSUSE/SLES

If you’re running something else obscure, install `x11vnc` manually first, then re-run the script.  

---

## Quick Start

1. Clone the repository and run the script as root:

   ```bash
   chmod +x x11vnc-setup.sh
   sudo ./x11vnc-setup.sh
   ```
2. Follow the prompts to:

- Set a VNC password

- Choose which user to run the service as

- (Optionally) configure a custom port

3. The script will:

- Install `x11vnc` if missing

- Install `autocutsel` to enable copy-paste support between the remote viewer and the host

- Configure the systemd service (auto-starts on boot)

- Show you how to connect, open the firewall, and check logs

---

## Known Limitations


### 1. Wayland is not supported
`x11vnc` **only works with X11** (XFCE, Mate, Cinnamon, etc). 

If you’re on Wayland, you probably **don't need this script at all.**

**GNOME Desktop (either Wayland or X11)**:
- Comes with built-in remote desktop support via `gnome-remote-desktop`
- Go to `Settings -> Sharing -> Screen Sharing` and enable it
- `gnome-remote-desktop` supports both VNC and RDP protocols

**KDE Plasma (either Wayland or X11)**:
- Built-in RDP server support
- Go to **System Settings -> Workspace -> Remote Desktop**
- Enable RDP server for remote access

**Other Wayland environments (like Sway)**
- This script won't work at all on them
- Use Wayland native solutions, such as `wayvnc`

### 2. The script assumes display `:0`
Fine for single-user desktops, but could be wrong for headless or multi-session machines.

**Solution**: Edit the `DISPLAY` in the systemd service if needed.

### 3. Logging to `/var/log/x11vnc.log` might fail for non-root users
The script directs logs to /var/log/x11vnc.log, but permissions might block non-root users.

**Solution**: Remove the `-o` flag and rely on `journalctl` logs.

### 4. Double forking via `-bg` and systemd `Type=forking`
The script uses both `-bg` and `Type=forking`. It works, but it’s not elegant.

**Solution**: Remove `-bg` and rely on systemd's forking behavior, or change `Type=simple`.

---

## Uninstallation

To remove x11vnc completely, use the provided uninstall script:

1. Clone the repository and run the script as root:

   ```bash
   chmod +x uninstall.sh
   sudo ./uninstall.sh
   ```
2. The script will:

- Stop and remove the `x11vnc` systemd service

- Remove all config files and directories

- Uninstall `x11vnc` and `autocutsel`

- Provide optional instructions	to cleanup the firewall	rules (if any)

---

License: MIT. Use freely, I'm not responsible if things break or catch fire.

Author: Dom

GitHub: @domomg

Contributions welcome. If you find a bug or need support for another distribution, feel free to open an issue or PR.
