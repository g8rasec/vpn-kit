#!/bin/bash
# Connects to the lab VPN (OpenVPN) with username + password.
# The password is never echoed and the credentials file lives in RAM
# (/dev/shm) only while the connection is up.
#
# Configuration comes from environment variables or the .env file (see
# env.example). No real values live in this script.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
env_user="${VPN_USER:-}"
# shellcheck disable=SC1091
[ -f "${REPO_DIR}/.env" ] && . "${REPO_DIR}/.env"
VPN_USER="${env_user:-${VPN_USER:-}}"

PROFILE="${VPN_LAB_PROFILE:-/etc/openvpn/client/lab.ovpn}"

if [ ! -f "$PROFILE" ]; then
    echo "Profile not found: $PROFILE"
    echo "Run ./install.sh with config/lab.ovpn in place (see README)."
    exit 1
fi

CREDS=$(mktemp -p /dev/shm vpn_lab_creds.XXXXXX)

cleanup() {
    rm -f "$CREDS"
}
trap cleanup EXIT

if [ -z "$VPN_USER" ]; then
    read -r -p "VPN username: " VPN_USER
else
    read -r -p "VPN username [$VPN_USER]: " input_user
    VPN_USER=${input_user:-$VPN_USER}
fi
read -r -s -p "VPN password: " VPN_PASS
echo

printf "%s\n%s\n" "$VPN_USER" "$VPN_PASS" > "$CREDS"
unset VPN_PASS

sudo openvpn --config "$PROFILE" --auth-user-pass "$CREDS"
