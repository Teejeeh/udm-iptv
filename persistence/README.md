# udm-iptv Persistent Installation

This directory contains scripts and configurations for **persistent udm-iptv installation** across UniFi OS updates.

## Overview

These scripts ensure that:

- Configuration persists across OS updates
- udm-iptv is automatically reinstalled if missing after an update
- Updates are checked and applied automatically every 24 hours
- The implementation works for future OS versions without code changes

## Files

### Management Scripts

- **`manage.sh`** — Enterprise-grade lifecycle manager (install/update/start/stop)
- **`unios_1.x.sh`** — Implementation for UniFi OS 1.x
- **`unios_2.x.sh`** — Implementation for UniFi OS 2.x and later

### Boot Integration

- **`on-boot.d/11-udm-iptv.sh`** — Boot script for persistent installation
- **`udm-iptv-env`** — Configuration file for auto-update behavior

### Systemd Integration

- **`udm-iptv-install.service`** — Systemd service for boot execution
- **`udm-iptv-install.timer`** — Systemd timer for periodic updates (24h)

### Utilities

- **`install-noninteractive.sh`** — Fallback non-interactive installer

## Installation

### Manual Installation

```bash
# On your workstation:
ssh <device> 'mkdir -p /data/udm-iptv /data/on_boot.d'
scp -r persistence/* <device>:/data/udm-iptv/
scp persistence/on-boot.d/11-udm-iptv.sh <device>:/data/on_boot.d/

# On device:
chmod +x /data/udm-iptv/*.sh /data/on_boot.d/*.sh
/data/udm-iptv/manage.sh on-boot
```

## Usage

```bash
/data/udm-iptv/manage.sh status     # Check service status
/data/udm-iptv/manage.sh start      # Start the service
/data/udm-iptv/manage.sh stop       # Stop the service
/data/udm-iptv/manage.sh restart    # Restart the service
/data/udm-iptv/manage.sh update     # Check for and apply updates
/data/udm-iptv/manage.sh install!   # Force reinstall
/data/udm-iptv/manage.sh uninstall  # Remove udm-iptv
```

## How It Works

### 1. Configuration Persistence

The boot script ensures:

- `/etc/udm-iptv.conf` is symlinked to `/data/udm-iptv/udm-iptv.conf`
- Configuration survives OS updates (stored in persistent `/data/` volume)
- Symlink is recreated if broken by an update

### 2. Boot-Time Installation

On every device boot:

1. Boot script detects OS version
2. If udm-iptv is not installed, it's automatically installed
3. Service is started with existing configuration
4. Auto-updates are checked if enabled

### 3. Automatic Updates

Systemd timer triggers daily:

- Checks for newer udm-iptv versions on GitHub
- Automatically installs updates if available
- First check happens 5 minutes after boot
- Subsequent checks every 24 hours

### 4. Future-Proof

Uses version comparison (`-ge 2`) instead of explicit version lists — automatically supports UniFi OS v6, v7, and beyond without code changes.

## Troubleshooting

### Installation Stuck on Configuration

```bash
/data/udm-iptv/install-noninteractive.sh
```

### Service Not Starting After Update

```bash
systemctl status udm-iptv.service
journalctl -u udm-iptv.service -n 20
/data/udm-iptv/manage.sh restart
```

### Disable Auto-Updates

Edit `/data/udm-iptv/udm-iptv-env`:

```bash
UDM_IPTV_AUTOUPDATE="false"
```

## Version Compatibility

| OS Version | Support            |
| ---------- | ------------------ |
| v1         | ✓ (uses /mnt/data) |
| v2–v5      | ✓ Tested           |
| v6+        | ✓ Future-proof     |

## License

Same as udm-iptv (GPLv2)
