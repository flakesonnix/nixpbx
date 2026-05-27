# FreePBX on NixOS

## Overview

FreePBX is an open-source, browser-based GUI that manages Asterisk, the most
widely deployed open-source PBX engine. Together they form a complete telephony
platform: Asterisk handles the actual call processing, codec negotiation, and
protocol state machines (SIP, PJSIP, IAX2, DAHDI), while FreePBX exposes all of
that through a web admin panel with a modular extension system — extensions,
trunks, IVRs, voicemail, call queues, ring groups, time conditions, and more.

Running FreePBX on NixOS gives you declarative, reproducible telephony
infrastructure. The entire system — web server, PHP runtime, Asterisk, MariaDB,
firewall rules, and FreePBX itself — is specified in one `configuration.nix`.
Rolling back a bad configuration is a single `nixos-rebuild switch --rollback`.
There are no hand-crafted `/etc` files that drift from the declared state.

FreePBX 17 is the first release to target PHP 8.2 and Debian-style deployments.
This packaging adapts that release to the Nix store model: read-only store paths
hold the immutable code, while `/var/lib/freepbx` holds all writable runtime
state. The `freepbx-init` systemd service bridges the two on first boot.

---

## Quick Start

### Minimal Configuration

Add to your `configuration.nix`:

```nix
{ config, pkgs, ... }:
{
  imports = [
    (builtins.fetchTarball "https://github.com/yourorg/nixpbx/archive/main.tar.gz"
      + "/nixos/modules/freepbx.nix")
  ];

  services.freepbx.enable = true;
  services.freepbx.database.passwordFile = "/run/secrets/freepbx-db-pass";
}
```

Or, using the flake as an input:

```nix
# flake.nix
{
  inputs.nixpbx.url = "github:yourorg/nixpbx";

  outputs = { nixpkgs, nixpbx, ... }: {
    nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
      modules = [
        nixpbx.nixosModules.freepbx
        {
          services.freepbx.enable = true;
          services.freepbx.database.passwordFile = "/run/secrets/freepbx-db-pass";
        }
      ];
    };
  };
}
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake .#myserver
```

### Production Configuration

```nix
services.freepbx = {
  enable = true;

  # Pin a specific package revision for stability
  package = pkgs.freepbx;

  database = {
    host         = "localhost";
    name         = "asterisk";
    user         = "asterisk";
    passwordFile = "/run/secrets/freepbx-db-pass";
  };

  adminPasswordFile = "/run/secrets/freepbx-admin-pass";

  # Open SIP (5060/5061) and RTP (10000–20000) in the firewall
  openFirewall   = true;
  sipPort        = 5060;
  tlsSipPort     = 5061;
  rtpPortRange   = { from = 10000; to = 20000; };

  extraConfig = ''
    $amp_conf['AMPDISABLELOG'] = 'false';
    $amp_conf['AMPASTERISKCONFDIR'] = '/etc/asterisk';
  '';
};

# Pair with agenix or sops-nix for secret management
age.secrets.freepbx-db-pass.file  = ./secrets/freepbx-db-pass.age;
age.secrets.freepbx-admin-pass.file = ./secrets/freepbx-admin-pass.age;
```

---

## Architecture

### Nix Store vs. Runtime State

The Nix store (`/nix/store/…`) is read-only. FreePBX expects to write to its
web root (for module installs), to `/etc/freepbx.conf`, and to various spool
and log directories. This packaging resolves the conflict as follows:

| Path | What lives there | Managed by |
|---|---|---|
| `/nix/store/…/share/freepbx/` | Immutable PHP source, AGI scripts | Nix derivation |
| `/var/lib/freepbx/www/` | Writable copy of web root | `freepbx-init` service |
| `/var/lib/freepbx/sessions/` | PHP session files | PHP-FPM |
| `/etc/freepbx.conf` | Runtime config (DB creds, paths) | `freepbx-init` service |
| `/etc/asterisk/` | Asterisk dialplan + config | Asterisk + FreePBX |
| `/var/spool/asterisk/` | Voicemail, recordings, call files | Asterisk |
| `/var/log/asterisk/` | Call logs, FreePBX logs | Asterisk + PHP-FPM |

### Service Layout

```
multi-user.target
  └── freepbx-init.service     (oneshot, runs on boot; requires mysql.service)
        └── httpd.service       (Apache + PHP-FPM, serves /var/lib/freepbx/www)
        └── asterisk.service    (PBX engine, reads /etc/asterisk/)
  └── freepbx-cron.timer       (every 5 min → freepbx-cron.service)
```

`freepbx-init` runs as root to copy files and write `/etc/freepbx.conf`, then
drops privileges. All other services run as the `asterisk` user.

---

## Upgrading

1. Update the flake input or bump the package version:
   ```bash
   nix flake update nixpbx
   ```
2. Rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#myserver
   ```
3. `freepbx-init` detects the new store path and re-deploys the web root.
   Database schema migrations run automatically via `fwconsole reload`.

To roll back:
```bash
sudo nixos-rebuild switch --rollback
```

---

## Adding Modules

Pass extra module derivations via `extraModules` in `pkgs.freepbx`:

```nix
services.freepbx.package = pkgs.freepbx.override {
  extraModules = [
    (pkgs.fetchFromGitHub {
      owner = "MyOrg";
      repo  = "freepbx-mymodule";
      rev   = "v1.2.3";
      hash  = "sha256-...";
    })
  ];
};
```

Each entry in `extraModules` is copied into
`/var/lib/freepbx/www/admin/modules/<basename>/`.

---

## Troubleshooting

### fwconsole Commands

```bash
# Reload Asterisk dialplan and FreePBX config
fwconsole reload

# Fix file ownership after manual edits
fwconsole chown

# List installed modules and their status
fwconsole moduleadmin list

# Run the cron job manually
fwconsole job --quiet

# Check FreePBX framework version
fwconsole --version
```

### Logs

```bash
# All FreePBX / Asterisk systemd output
journalctl -u freepbx-init -u asterisk -u httpd -f

# PHP-FPM errors
journalctl -u phpfpm-freepbx -f

# Asterisk full log
tail -f /var/log/asterisk/full

# FreePBX module log
tail -f /var/log/asterisk/freepbx.log
```

### Asterisk CLI

```bash
asterisk -rvvvv
```

Useful CLI commands once connected:

```
core show version
pjsip show endpoints
dialplan show
core reload
```

---

## Security Considerations

- **Never inline secrets.** Use `database.passwordFile` and `adminPasswordFile`
  pointing to paths managed by agenix, sops-nix, or another secrets manager.
  `/etc/freepbx.conf` is written at runtime with `chmod 640` and owned
  `root:asterisk`.

- **SIP hardening.** Enable `openFirewall` only on the WAN interface if possible.
  Use `networking.firewall.interfaces` for per-interface rules. Consider deploying
  fail2ban watching `/var/log/asterisk/full` for SIP auth failures.

- **TLS SIP.** Configure PJSIP transport in Asterisk with a Let's Encrypt
  certificate. Set `tlsSipPort` and ensure `openFirewall = true` opens port 5061.

- **Web admin access.** Do not expose port 80/443 to the public internet unless
  you have a reverse proxy with authentication in front of the FreePBX admin.
  The admin panel has no rate limiting by default.

- **Asterisk AMI.** The Asterisk Manager Interface listens on port 5038 by default.
  Restrict it to `localhost` in `manager.conf` unless you have a specific need.

---

## Known Limitations

- **Not an official upstream packaging.** Sangoma (the FreePBX maintainer) does
  not provide NixOS packages. This flake tracks the upstream GitHub repos and may
  lag behind urgent security releases.

- **Commercial modules are excluded.** Sangoma's commercial modules (Zulu UC,
  SIPStation, CXPanel, etc.) use IonCube loader-encrypted PHP and cannot be
  built from source. They are not packaged here and cannot be.

- **Mutable web root.** FreePBX's module manager writes PHP files at runtime.
  Modules installed via the web UI survive reboots (they're in `/var/lib/freepbx/www`)
  but are not managed by Nix and will not appear in `nix flake check`. Treat them
  as ephemeral state or track them via the `extraModules` mechanism.

- **Asterisk module set.** `pkgs.asterisk` in nixpkgs may not include every
  optional Asterisk module FreePBX expects. Use `pkgs.asterisk.override` or
  `pkgs.asterisk.overrideAttrs` to enable additional compile-time options if you
  encounter missing module warnings in the FreePBX admin panel.
