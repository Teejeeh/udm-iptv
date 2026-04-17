#!/bin/sh
set -e

PACKAGE_ROOT="${PACKAGE_ROOT:-"$(dirname -- "$(readlink -f -- "$0";)")"}"
if [ -x "$(which ubnt-device-info)" ]; then
  OS_VERSION="${FW_VERSION:-$(ubnt-device-info firmware_detail | grep -oE '^[0-9]+')}"
elif [ -f "/usr/lib/version" ]; then
  # UCKP == Unifi CloudKey Gen2 Plus
  # example /usr/lib/version file contents:
  # UCKP.apq8053.v2.5.11.b2ebfc7.220801.1419
  # UCKP.apq8053.v3.0.17.8102bbc.230210.1526
  # UCKG2 == UniFi CloudKey Gen2
  # example /usr/lib/version file contents:
  # UCKG2.apq8053.v3.1.13.3584673.230626.2239
  if [ "$(grep -c '^UCKP.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UCKP.*.v\(.\)\..*/\1/' /usr/lib/version)"
  elif [ "$(grep -c '^UCKG2.*\.v[0-9]\.' /usr/lib/version)" = '1' ]; then
    OS_VERSION="$(sed -e 's/UCKG2.*.v\(.\)\..*/\1/' /usr/lib/version)"
  else
    echo "Could not detect OS Version.  /usr/lib/version contains:"
    cat /usr/lib/version
    exit 1
  fi
else
  echo "Could not detect OS Version.  No ubnt-device-info, no version file."
  exit 1
fi

if [ "$OS_VERSION" = '1' ]; then
  # shellcheck source=package/unios_1.x.sh
  . "$PACKAGE_ROOT/unios_1.x.sh"
elif [ "$OS_VERSION" -ge '2' ] 2>/dev/null; then
  # OS versions 2 and above share the same implementation
  # shellcheck source=package/unios_2.x.sh
  . "$PACKAGE_ROOT/unios_2.x.sh"
else
  echo "Unsupported UniFi OS version (v$OS_VERSION)."
  echo "Please provide the following information to us on GitHub:"
  echo "# /usr/bin/ubnt-device-info firmware_detail"
  /usr/bin/ubnt-device-info firmware_detail
  echo ""
  echo "# /etc/os-release"
  cat /etc/os-release
  exit 1
fi

udm_iptv_status() {
  if ! _udm_iptv_is_installed; then
    echo "udm-iptv is not installed"
    exit 1
  elif _udm_iptv_is_running; then
    echo "udm-iptv is running"
    udm-iptv --version
  else
    echo "udm-iptv is not running"
  fi
}

udm_iptv_start() {
  _udm_iptv_start
}

udm_iptv_stop() {
  echo "Stopping udm-iptv..."
  _udm_iptv_stop
}

udm_iptv_install() {
  _udm_iptv_install

  echo "Installation complete, run '$0 start' to start udm-iptv"
}

udm_iptv_uninstall() {
  echo "Removing udm-iptv"
  _udm_iptv_uninstall
}

udm_iptv_has_update() {
  if ! _udm_iptv_is_installed; then
    return 1
  fi

  CURRENT_VERSION="$(_udm_iptv_get_version)"
  TARGET_VERSION="${1:-$(curl --ipv4 -sSLq 'https://api.github.com/repos/fabianishere/udm-iptv/releases/latest' | grep -oE '"tag_name": "[^"]*"' | cut -d'"' -f4 | sed 's/^v//')}"

  if [ -z "$CURRENT_VERSION" ] || [ -z "$TARGET_VERSION" ]; then
    return 1
  fi

  if [ "${CURRENT_VERSION}" != "${TARGET_VERSION}" ]; then
    return 0
  else
    return 1
  fi
}

udm_iptv_update() {
  udm_iptv_stop
  udm_iptv_install
  udm_iptv_start
}

case $1 in
  "status")
    udm_iptv_status
    ;;
  "start")
    udm_iptv_start
    ;;
  "stop")
    udm_iptv_stop
    ;;
  "restart")
    udm_iptv_stop
    udm_iptv_start
    ;;
  "install")
    if _udm_iptv_is_running; then
      echo "udm-iptv is already installed and running, if you wish to update it, run '$0 update'"
      echo "If you wish to force a reinstall, run '$0 install!'"
      exit 0
    fi

    udm_iptv_install "$2"
    ;;
  "install!")
    udm_iptv_install "$2"
    ;;
  "uninstall")
    udm_iptv_stop
    udm_iptv_uninstall
    ;;
  "update")
    if udm_iptv_has_update "$2"; then
      if _udm_iptv_is_running; then
        echo "udm-iptv is running, stopping for update..."
      fi

      udm_iptv_update "$2"
    else
      echo "udm-iptv is already up to date"
    fi
    ;;
  "update!")
    if udm_iptv_has_update "$2"; then
      udm_iptv_update "$2"
    else
      echo "udm-iptv is already up to date"
    fi
    ;;
  "on-boot")
    # shellcheck source=package/udm-iptv-env
    . "${PACKAGE_ROOT}/udm-iptv-env"

    if ! _udm_iptv_is_installed; then
      udm_iptv_install
    fi

    if [ "${UDM_IPTV_AUTOUPDATE}" = "true" ]; then
      udm_iptv_has_update && udm_iptv_update || logger "udm-iptv: already up to date"
    fi

    udm_iptv_start
    ;;
  *)
    echo "Usage: $0 {status|start|stop|restart|install|uninstall|update|on-boot}"
    exit 1
    ;;
esac
