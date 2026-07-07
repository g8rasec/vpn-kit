#!/bin/bash
# Connects to the corporate VPN (Fortinet SSL VPN) with SAML/SSO login.
# The SSO happens in a browser; on a headless server, forward the SAML port
# from your workstation first:  ssh -L 8020:127.0.0.1:8020 <this-server>
#
# Configuration comes from environment variables or the .env file (see
# env.example). No real values live in this script.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
[ -f "${REPO_DIR}/.env" ] && . "${REPO_DIR}/.env"

GATEWAY="${VPN_CORP_GATEWAY:-}"
PORT="${VPN_CORP_PORT:-443}"
SAML_PORT="${VPN_CORP_SAML_PORT:-8020}"

if [ -z "$GATEWAY" ]; then
    echo "VPN_CORP_GATEWAY is not set."
    echo "Create the .env file from env.example:  cp env.example .env"
    exit 1
fi

echo "Connecting to ${GATEWAY}:${PORT} (SSO via browser)..."
echo "Open the URL printed below in a browser to authenticate."
echo "No browser on this machine? On your workstation run:" \
     "ssh -L ${SAML_PORT}:127.0.0.1:${SAML_PORT} $(hostname)"
echo

exec sudo openfortivpn "${GATEWAY}:${PORT}" --saml-login="${SAML_PORT}"
