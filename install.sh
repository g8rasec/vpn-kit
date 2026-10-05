#!/bin/bash
# Installs the clients for both VPNs:
#  - openfortivpn, built from the source vendored in third_party/ — no
#    external download (the distro package is too old for SAML)
#  - openvpn (distro package) + the lab profile, if config/lab.ovpn exists
set -euo pipefail

OPENFORTIVPN_VERSION="1.23.1"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
[ -f "${REPO_DIR}/.env" ] && . "${REPO_DIR}/.env"

SRC_DIR="${REPO_DIR}/third_party/openfortivpn-${OPENFORTIVPN_VERSION}"
LAB_PROFILE_DST="${VPN_LAB_PROFILE:-/etc/openvpn/client/lab.ovpn}"

# Any .ovpn dropped into config/ (whatever its original name) is the lab
# profile candidate
shopt -s nullglob
lab_profiles=("${REPO_DIR}/config/"*.ovpn)
shopt -u nullglob

echo "== [1/3] Dependencies (apt) =="
sudo apt-get update -qq
sudo apt-get install -y build-essential automake autoconf pkg-config \
    libssl-dev ppp openvpn tmux

echo "== [2/3] openfortivpn ${OPENFORTIVPN_VERSION} (vendored source) =="
if command -v openfortivpn >/dev/null &&
        openfortivpn --version 2>/dev/null | grep -q "^${OPENFORTIVPN_VERSION}$"; then
    echo "openfortivpn ${OPENFORTIVPN_VERSION} already installed — skipping build."
else
    # Build in a temporary copy so the vendored source stays pristine
    build_dir=$(mktemp -d)
    trap 'rm -rf "$build_dir"' EXIT
    cp -a "$SRC_DIR" "$build_dir/"
    (
        cd "$build_dir/openfortivpn-${OPENFORTIVPN_VERSION}"
        ./autogen.sh
        ./configure --prefix=/usr/local --sysconfdir=/etc
        make -j"$(nproc)"
        sudo make install
    )
    echo "openfortivpn installed: $(openfortivpn --version)"
fi

echo "== [3/3] Lab OpenVPN profile =="
if [ "${#lab_profiles[@]}" -gt 1 ]; then
    echo "ERROR: more than one .ovpn found in config/ — keep only the right one:"
    printf '  %s\n' "${lab_profiles[@]}"
    exit 1
elif [ "${#lab_profiles[@]}" -eq 1 ]; then
    # Move, not copy: the private key must not stay inside the repo dir
    sudo install -m 600 -D "${lab_profiles[0]}" "$LAB_PROFILE_DST"
    rm -f "${lab_profiles[0]}"
    echo "Profile '$(basename "${lab_profiles[0]}")' installed at" \
         "$LAB_PROFILE_DST (copy removed from config/)"
elif [ -f "$LAB_PROFILE_DST" ]; then
    echo "Profile already installed at $LAB_PROFILE_DST — ok."
else
    echo "NOTICE: no profile installed yet."
    echo "Download the .ovpn (any file name) into ${REPO_DIR}/config/ and run"
    echo "this script again — it installs it and deletes the copy from config/."
fi

echo
echo "Installation done. Configure with 'cp env.example .env' (if not done yet)"
echo "and connect with ./vpn-corp.sh or ./vpn-lab.sh"
