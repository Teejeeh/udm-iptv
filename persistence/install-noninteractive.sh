#!/bin/sh
# Non-interactive udm-iptv installation recovery script

set -e

echo "=== udm-iptv Non-Interactive Installation ==="

# Clean up any broken state
echo "Cleaning up broken installation..."
DEBIAN_FRONTEND=noninteractive apt-get remove -y udm-iptv 2>/dev/null || true
apt-get clean
rm -rf /tmp/tmp.* /var/cache/apt/archives/*udm-iptv* 2>/dev/null || true

# Update package cache
echo "Updating package cache..."
apt-get update >/dev/null 2>&1 || true

# Install with non-interactive mode - don't ask questions
echo "Installing udm-iptv non-interactively..."
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Pre-seed debconf before installation
echo "Pre-seeding configuration..."
echo "udm-iptv udm-iptv/wan_interface select eth0" | debconf-set-selections 2>/dev/null || true
echo "udm-iptv udm-iptv/vlan_enabled boolean true" | debconf-set-selections 2>/dev/null || true
echo "udm-iptv udm-iptv/vlan_id string 4" | debconf-set-selections 2>/dev/null || true

# Download and install fresh
if curl -sSf https://raw.githubusercontent.com/fabianishere/udm-iptv/master/install.sh > /tmp/udm-iptv-install.sh; then
    chmod +x /tmp/udm-iptv-install.sh
    /tmp/udm-iptv-install.sh || {
        echo "Primary installer failed, trying dpkg directly..."
        # Try completing any partial installation
        DEBIAN_FRONTEND=noninteractive dpkg --configure -a || true
    }
else
    echo "Failed to download installer"
    exit 1
fi

echo ""
echo "=== Verification ==="
if command -v udm-iptv >/dev/null 2>&1; then
    echo "udm-iptv is installed at: $(which udm-iptv)"
    udm-iptv --version 2>/dev/null || echo "Version check not available"
else
    echo "udm-iptv still not found in PATH"
    exit 1
fi

echo "Installation complete"
