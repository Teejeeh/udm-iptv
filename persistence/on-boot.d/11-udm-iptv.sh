#!/bin/sh
set -e

# Ensure udm-iptv config is persisted in device persistent storage
# Detect Ubiquiti OS version like other on-boot scripts
if [ -x "$(which ubnt-device-info)" ]; then
  OS_VERSION="${FW_VERSION:-$(ubnt-device-info firmware_detail | grep -oE '^[0-9]+')}"
elif [ -f "/usr/lib/version" ]; then
  if [ "$(grep -c '^UCKP.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UCKP.*.v\(.\)\..*/\1/' /usr/lib/version)"
  elif [ "$(grep -c '^UCKG2.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UCKG2.*.v\(.\)\..*/\1/' /usr/lib/version)"
  else
    logger "udm-iptv: Could not detect OS Version. /usr/lib/version contains:"
    cat /usr/lib/version
    exit 1
  fi
else
  logger "udm-iptv: Could not detect OS Version. No ubnt-device-info, no version file."
  exit 1
fi

if [ "$OS_VERSION" = '1' ]; then
  PERSIST_ROOT="/mnt/data"
else
  # OS versions 2+ all use /data
  PERSIST_ROOT="/data"
fi

PERSIST_CONF="$PERSIST_ROOT/udm-iptv/udm-iptv.conf"

# Ensure persistent directory exists
mkdir -p "$PERSIST_ROOT/udm-iptv"

if [ -f "$PERSIST_CONF" ]; then
  # make sure /etc/udm-iptv.conf points to persistent copy
  if [ ! -L /etc/udm-iptv.conf ]; then
    if [ -f /etc/udm-iptv.conf ]; then
      cp -a /etc/udm-iptv.conf "$PERSIST_CONF" || true
    fi
    ln -sf "$PERSIST_CONF" /etc/udm-iptv.conf
  fi
  logger "udm-iptv: using existing persistent config $PERSIST_CONF"
elif [ -f /etc/udm-iptv.conf ]; then
  # move existing system config into persistent storage and symlink
  cp -a /etc/udm-iptv.conf "$PERSIST_CONF"
  ln -sf "$PERSIST_CONF" /etc/udm-iptv.conf
  logger "udm-iptv: moved /etc/udm-iptv.conf -> $PERSIST_CONF and symlinked"
else
  # create an empty persistent config so package can use it
  touch "$PERSIST_CONF"
  ln -sf "$PERSIST_CONF" /etc/udm-iptv.conf
  logger "udm-iptv: created empty persistent config at $PERSIST_CONF"
fi

# Use the centralized manage.sh script
$PERSIST_ROOT/udm-iptv/manage.sh on-boot

exit 0
