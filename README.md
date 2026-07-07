# vpn-kit

Scripts to install and connect two VPNs on Ubuntu/Debian machines
(workstation or headless server):

| VPN | Technology | Client | Authentication |
|---|---|---|---|
| **Corporate** | Fortinet SSL VPN | [openfortivpn](https://github.com/adrienverge/openfortivpn) (vendored source, with SAML support) | SSO in the browser |
| **Lab** | OpenVPN | openvpn | username + password |

No real values (gateway, ports, credentials) are versioned — everything comes
from the local `.env` file or environment variables.

## Installation

```bash
git clone <this-repo> && cd <repo>
./install.sh
cp env.example .env   # then fill in the real values
```

The installer:

1. installs the dependencies (`build-essential`, `ppp`, `openvpn`, ...);
2. builds `openfortivpn` from the **source vendored in `third_party/`** — no
   external download; what gets installed is exactly the auditable code
   versioned in this repository (the version in Ubuntu's repositories is too
   old for SAML/SSO). Skipped if already installed;
3. installs the lab profile (see below), if `config/lab.ovpn` exists.

### Lab profile (manual, once per machine)

The `.ovpn` file contains a **certificate and a private key** — that is why
it is **never versioned** (see `.gitignore`). The `config/` directory is the
**drop zone**: download/copy the profile you received from IT into it — with
**any file name** — and run the installer. It moves the file to its final
home (`/etc/openvpn/client/lab.ovpn`, with restricted permissions) and
**deletes the copy from `config/`**, so no secret stays inside the
repository:

```bash
mv ~/Downloads/received-profile.ovpn config/   # or scp from another machine
./install.sh   # safe to run again; installs the profile, no recompilation
```

If more than one `.ovpn` is present in `config/`, the installer aborts and
asks you to keep only the right one.

## Configuration

Everything variable (gateway, ports, profile path) comes from environment
variables or the `.env` file (not versioned):

```bash
cp env.example .env   # then fill in
```

Environment variables exported in the shell take precedence over `.env`.
See all variables in [`env.example`](env.example). The corporate VPN
**requires** `VPN_CORP_GATEWAY` to be set — the script aborts with
instructions if it is missing.

## Usage

### Corporate VPN (SSO)

```bash
./vpn-corp.sh
```

The script connects and prints a URL. Open it **in a browser** and complete
the SSO login. Keep the terminal open — `Ctrl+C` disconnects.

**On a server without a browser (headless):** the SSO login happens in your workstation's browser, through an SSH port-forward.

```text
[ Browser (Workstation) ]
         │
         │ 1. Access http://127.0.0.1:8020 (SSO token redirect)
         ▼
[ Port 8020 (Workstation) ] ◄── (SSH listens here)
         │
         │ 2. Forwarded over secure SSH tunnel
         ▼
[ Port 8020 (Headless Server) ]
         │
         │ 3. Delivered locally
         ▼
[ openfortivpn / vpn-corp.sh ] ──► Tunnel Established! 🎉
```

1. On your workstation, open an auxiliary terminal and run:
   ```bash
   ssh -L 8020:127.0.0.1:8020 <server-ip-or-host>
   ```
   *(Tip: If hostname resolution fails, use the server's local IP address, e.g., `192.168.1.10`).*

2. On the server, run `./vpn-corp.sh`. It will listen for SAML on port 8020 and print a login URL.

3. Copy that URL, open it in your workstation's browser, and complete the SSO authentication.

4. Once the tunnel is established (`Tunnel is up and running`), the login token has been received and you can safely close the auxiliary SSH port-forwarding terminal.



### Lab VPN

```bash
./vpn-lab.sh
```

Prompts for username and password (the password is never echoed and never
touches a permanent file). `Ctrl+C` disconnects.

## Updating the vendored openfortivpn

The source in `third_party/openfortivpn-<version>/` is a frozen copy
([vendoring](https://en.wikipedia.org/wiki/Vendoring)) of the
[official project](https://github.com/adrienverge/openfortivpn) (GPL-3.0 with
OpenSSL exception — license included in the directory). Freezing protects
against a future compromise of the upstream repository, but it also freezes
fixes: **from time to time, check the
[changelog](https://github.com/adrienverge/openfortivpn/blob/master/CHANGELOG.md)**
and, when a relevant security fix lands:

```bash
# download the new version tarball, review the diff and replace the directory
wget https://github.com/adrienverge/openfortivpn/archive/refs/tags/vX.Y.Z.tar.gz
tar xf vX.Y.Z.tar.gz -C third_party/
git rm -r third_party/openfortivpn-<old-version>
# update OPENFORTIVPN_VERSION in install.sh and commit
```

## Notes

- Both scripts use `sudo` (creating network interfaces requires root).
- Both VPNs change routes and DNS — avoid connecting both at the same time
  unless you know what you are doing.
