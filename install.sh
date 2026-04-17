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

mkdir -p "$PERSIST_DIR" "$ON_BOOT_DIR"

# Copy persistence files from package
if [ -d /usr/lib/udm-iptv/persistence ]; then
    cp -r /usr/lib/udm-iptv/persistence/* "$PERSIST_DIR/"
    cp /usr/lib/udm-iptv/persistence/on-boot.d/11-udm-iptv.sh "$ON_BOOT_DIR/"
    chmod +x "$PERSIST_DIR"/*.sh "$ON_BOOT_DIR"/*.sh
    echo "Persistence scripts deployed from package"
else
    echo "Warning: persistence scripts not found in package"
fi

# Symlink /etc/udm-iptv.conf to persistent storage
PERSIST_CONF="$PERSIST_DIR/udm-iptv.conf"
[ ! -f "$PERSIST_CONF" ] && [ -f /etc/udm-iptv.conf ] && cp -a /etc/udm-iptv.conf "$PERSIST_CONF"
[ ! -L /etc/udm-iptv.conf ] && ln -sf "$PERSIST_CONF" /etc/udm-iptv.conf

echo "Configuration will persist across OS updates at $PERSIST_CONF"
