#!/bin/sh
# Installation script for the udm-iptv service
#
# Copyright (C) 2022 Fabian Mastenbroek.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

set -e

if command -v unifi-os > /dev/null 2>&1; then
    echo "error: You need to be in UniFi OS to run the installer."
    echo "Please run the following command to enter UniFi OS:"
    echo
    printf "\t unifi-os shell\n"
    exit 1
fi

UDM_IPTV_VERSION=3.0.6

dest=$(mktemp -d)

echo "Downloading packages..."

# Download udm-iptv package
curl -sS -o "$dest/udm-iptv.deb" -L "https://github.com/fabianishere/udm-iptv/releases/download/v$UDM_IPTV_VERSION/udm-iptv_${UDM_IPTV_VERSION}_all.deb"

# Fix permissions on the packages
chown _apt:root "$dest/udm-iptv.deb"

echo "Installing packages..."

# Update APT sources (best effort)
apt-get update 2>&1 1>/dev/null || true

# Install dialog package for interactive install
apt-get install -q -y dialog 2>&1 1>/dev/null || echo "Failed to install dialog... Using readline frontend"

# Install udm-iptv
apt-get install -o Acquire::AllowUnsizedPackages=1 -q "$dest/udm-iptv.deb"

# Delete downloaded packages
rm -rf "$dest"

echo "Installation successful... You can find your configuration at /etc/udm-iptv.conf."
echo
echo "Use the following command to reconfigure the script:"
echo
printf "\t udm-iptv reconfigure\n"

echo
echo "Setting up persistent installation..."

# v1 uses /mnt/data, v2+ uses /data
PERSIST_ROOT="$( [ -d /data ] && echo /data || echo /mnt/data )"
PERSIST_DIR="$PERSIST_ROOT/udm-iptv"
ON_BOOT_DIR="$PERSIST_ROOT/on_boot.d"

echo "Creating persistence directories: $PERSIST_DIR and $ON_BOOT_DIR"
mkdir -p "$PERSIST_DIR" "$ON_BOOT_DIR" || {
    echo "ERROR: Failed to create persistence directories!"
    exit 1
}

# Try to copy persistence files from different sources:
# 1. From installed package (if already in .deb)
# 2. From local repo (for development/testing)
# 3. Download from GitHub (fallback)

_files_deployed=false

if [ -d /usr/lib/udm-iptv/persistence ]; then
    echo "Found persistence files in installed package, copying..."
    cp -r /usr/lib/udm-iptv/persistence/* "$PERSIST_DIR/" && \
    cp /usr/lib/udm-iptv/persistence/on-boot.d/11-udm-iptv.sh "$ON_BOOT_DIR/" && \
    echo "✓ Persistence scripts deployed from installed package" && \
    _files_deployed=true
fi

if [ "$_files_deployed" = "false" ] && [ -d "/tmp/udm-iptv-src/persistence" ]; then
    echo "Found persistence files in local source, copying..."
    cp -r /tmp/udm-iptv-src/persistence/* "$PERSIST_DIR/" && \
    cp /tmp/udm-iptv-src/persistence/on-boot.d/11-udm-iptv.sh "$ON_BOOT_DIR/" && \
    echo "✓ Persistence scripts deployed from local source" && \
    _files_deployed=true
fi

if [ "$_files_deployed" = "false" ]; then
    echo "Downloading persistence scripts from GitHub..."
    
    # Try development fork first, then official
    for _github_source in "Teejeeh" "fabianishere"; do
        echo "  Trying ${_github_source}/udm-iptv..."
        
        # Download each file individually so we can see which fail
        _download_count=0
        
        for _file in manage.sh unios_1.x.sh unios_2.x.sh install-noninteractive.sh udm-iptv-env udm-iptv-install.service udm-iptv-install.timer; do
            if curl -sSf -o "$PERSIST_DIR/$_file" "https://raw.githubusercontent.com/${_github_source}/udm-iptv/master/persistence/$_file" 2>/dev/null; then
                _download_count=$(((_download_count + 1)))
            fi
        done
        
        # Try boot script
        if curl -sSf -o "$ON_BOOT_DIR/11-udm-iptv.sh" "https://raw.githubusercontent.com/${_github_source}/udm-iptv/master/persistence/on-boot.d/11-udm-iptv.sh" 2>/dev/null; then
            _download_count=$(((_download_count + 1)))
        fi
        
        # If we got all 9 files (8 scripts + boot script), we're done
        if [ $_download_count -eq 9 ]; then
            echo "✓ Downloaded all persistence scripts from https://github.com/${_github_source}/udm-iptv"
            _files_deployed=true
            break
        else
            echo "  Only got $_download_count/9 files from ${_github_source}, trying next source..."
        fi
    done
fi

# Make all scripts executable
if [ -f "$PERSIST_DIR/manage.sh" ]; then
    chmod +x "$PERSIST_DIR"/*.sh "$ON_BOOT_DIR"/*.sh 2>/dev/null || true
    echo "✓ Made persistence scripts executable"
fi

if [ "$_files_deployed" = "false" ]; then
    echo "WARNING: Could not deploy persistence scripts. Continuing anyway..."
fi

# Make all scripts executable
chmod +x "$PERSIST_DIR"/*.sh "$ON_BOOT_DIR"/*.sh 2>/dev/null || true

# Symlink /etc/udm-iptv.conf to persistent storage
PERSIST_CONF="$PERSIST_DIR/udm-iptv.conf"
[ ! -f "$PERSIST_CONF" ] && [ -f /etc/udm-iptv.conf ] && cp -a /etc/udm-iptv.conf "$PERSIST_CONF"
[ ! -L /etc/udm-iptv.conf ] && ln -sf "$PERSIST_CONF" /etc/udm-iptv.conf

echo "Configuration will persist across OS updates at $PERSIST_CONF"
