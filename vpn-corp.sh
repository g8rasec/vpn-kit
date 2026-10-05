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

if [ -z "${TMUX:-}" ]; then
    if ! command -v tmux >/dev/null 2>&1; then
        echo "tmux is required. Install it with: sudo apt-get install tmux"
        exit 1
    fi
    # Quote the script path and resolved settings for tmux's shell command.
    printf -v vpn_command '%q ' env \
        "VPN_CORP_GATEWAY=$GATEWAY" "VPN_CORP_PORT=$PORT" \
        "VPN_CORP_SAML_PORT=$SAML_PORT" "${REPO_DIR}/vpn-corp.sh"
    echo "Opening tmux session 'vpn' (or attaching if it already exists)."
    exec tmux new-session -A -s vpn "$vpn_command"
fi

SSH_HOST=""
while [ -z "$SSH_HOST" ]; do
    if ! read -r -p "SSH host/alias from your workstation (e.g. vpn-server): " SSH_HOST; then
        echo "A terminal is required to enter the SSH host/alias."
        exit 1
    fi
done

echo "Connecting to ${GATEWAY}:${PORT} (SSO via browser)..."
echo "Open the URL printed below in a browser to authenticate."
echo "No browser on this machine? On your workstation run:"
printf 'ssh -L %q %q\n' "${SAML_PORT}:127.0.0.1:${SAML_PORT}" "$SSH_HOST"
echo "After connecting, detach with Ctrl+B, then D to keep the VPN running."
echo "Return with: tmux attach -t vpn (or your existing tmux session)."
echo

exec sudo openfortivpn "${GATEWAY}:${PORT}" --saml-login="${SAML_PORT}"
