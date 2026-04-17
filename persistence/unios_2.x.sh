#!/bin/sh
export UDM_IPTV_ROOT="${UDM_IPTV_ROOT:-/data/udm-iptv}"

_udm_iptv_is_running() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet udm-iptv.service 2>/dev/null
    else
        # Fallback: check if process is running
        pgrep -f udm-iptv >/dev/null 2>&1
    fi
}

_udm_iptv_is_installed() {
    command -v udm-iptv >/dev/null 2>&1
}

_udm_iptv_get_version() {
    if _udm_iptv_is_installed; then
        udm-iptv --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo ""
    else
        echo ""
    fi
}

_udm_iptv_start() {
    echo "Starting udm-iptv..."

    if command -v systemctl >/dev/null 2>&1; then
        systemctl start udm-iptv.service

        # Wait a few seconds for the service to start
        sleep 3

        if _udm_iptv_is_running; then
            logger "udm-iptv: started successfully"
            echo "udm-iptv started successfully"
        else
            logger "udm-iptv: failed to start"
            echo "udm-iptv failed to start"
            exit 1
        fi
    else
        logger "udm-iptv: systemctl not available"
        echo "systemctl not available, cannot start udm-iptv"
        exit 1
    fi
}

_udm_iptv_stop() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop udm-iptv.service 2>/dev/null || true
        logger "udm-iptv: stopped"
    fi
}

_udm_iptv_install() {
    logger "udm-iptv: installing from GitHub..."
    _BRANCH="${UDM_IPTV_BRANCH:-master}"
    curl -sSf "https://raw.githubusercontent.com/fabianishere/udm-iptv/${_BRANCH}/install.sh" | sh
    logger "udm-iptv: installation completed"
}

_udm_iptv_uninstall() {
    logger "udm-iptv: uninstalling..."

    if command -v systemctl >/dev/null 2>&1; then
        systemctl disable udm-iptv.service 2>/dev/null || true
        systemctl stop udm-iptv.service 2>/dev/null || true
    fi

    # Try to run uninstall script if available
    if [ -f "/opt/udm-iptv/uninstall.sh" ]; then
        sh /opt/udm-iptv/uninstall.sh || true
    fi

    # Also try the GitHub uninstall method
    if curl -sSf https://raw.githubusercontent.com/fabianishere/udm-iptv/master/uninstall.sh | sh -s --; then
        logger "udm-iptv: uninstall completed"
    else
        logger "udm-iptv: uninstall script not available or failed"
    fi
}
