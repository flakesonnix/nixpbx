# FreePBX NixOS Options Reference

All options live under `services.freepbx`.

---

## `services.freepbx.enable`

**Type:** `bool`  
**Default:** `false`

Enable the FreePBX service. Activates MariaDB, Apache, PHP-FPM, Asterisk,
and the `freepbx-init` and `freepbx-cron` systemd units.

```nix
services.freepbx.enable = true;
```

---

## `services.freepbx.package`

**Type:** `package`  
**Default:** set automatically by `nixosModules.freepbx` via the flake overlay

The FreePBX package to use. When importing the module through the nixpbx flake
(`nixpbx.nixosModules.freepbx`), this is set to `pkgs.freepbx` from the flake's
overlay. Override to pin a specific version or add extra modules:

```nix
services.freepbx.package = pkgs.freepbx.override {
  extraModules = [ myCustomModule ];
};
```

---

## `services.freepbx.dataDir`

**Type:** `str`  
**Default:** `"/var/lib/freepbx"`

Root directory for all writable FreePBX runtime state. The `freepbx-init`
service creates subdirectories (`www/`, `sessions/`, `cache/`) here on first
boot. The default for `webRoot` is derived from this value.

Change this if you want FreePBX state on a dedicated partition or a network
volume:

```nix
services.freepbx.dataDir = "/mnt/freepbx-data";
```

**Note:** `StateDirectory` in the systemd unit always creates
`/var/lib/freepbx` as the actual on-disk location (systemd requires relative
paths). If you set `dataDir` to something outside `/var/lib/`, you must create
and chown the directory yourself before the service starts.

---

## `services.freepbx.asteriskPackage`

**Type:** `package`  
**Default:** `pkgs.asterisk`

The Asterisk PBX package. Override if you need a version with additional
compile-time options:

```nix
services.freepbx.asteriskPackage = pkgs.asterisk.overrideAttrs (old: {
  configureFlags = old.configureFlags ++ [ "--with-dahdi" ];
});
```

---

## `services.freepbx.user`

**Type:** `str`  
**Default:** `"asterisk"`

System user that owns FreePBX files and runs the Asterisk daemon.
Must have read access to `/etc/freepbx.conf`.

---

## `services.freepbx.group`

**Type:** `str`  
**Default:** `"asterisk"`

System group for the FreePBX user. The PHP-FPM pool and Apache both need
to be able to access the socket via this group.

---

## `services.freepbx.webRoot`

**Type:** `str`  
**Default:** `"/var/lib/freepbx/www"`

Writable directory where FreePBX PHP files are deployed at runtime.
The Nix store is read-only, so `freepbx-init` copies files here on first boot.
Must be writable by `cfg.user`.

---

## `services.freepbx.logDir`

**Type:** `str`  
**Default:** `"/var/log/asterisk"`

Directory for Asterisk and FreePBX log files. Created by `freepbx-init`
with ownership `cfg.user:cfg.group`.

---

## `services.freepbx.spoolDir`

**Type:** `str`  
**Default:** `"/var/spool/asterisk"`

Asterisk spool directory. Voicemail, recorded calls, and call files live here.
Must be writable by `cfg.user`.

---

## `services.freepbx.database.host`

**Type:** `str`  
**Default:** `"localhost"`

Hostname or IP of the MariaDB/MySQL server. For a local MariaDB instance
(the default) leave this at `"localhost"`.

---

## `services.freepbx.database.name`

**Type:** `str`  
**Default:** `"asterisk"`

Name of the FreePBX database. `services.mysql.ensureDatabases` creates this
database automatically.

---

## `services.freepbx.database.user`

**Type:** `str`  
**Default:** `"asterisk"`

MariaDB user for FreePBX. Granted `ALL PRIVILEGES` on `database.name` by
`services.mysql.ensureUsers`.

---

## `services.freepbx.database.passwordFile`

**Type:** `null or path`  
**Default:** `null`

Path to a file containing the MariaDB password for `database.user`.
The file is read at boot by `freepbx-init` and written into `/etc/freepbx.conf`
with mode `640`.

**Security:** Never put the password inline in your configuration. Use agenix,
sops-nix, or systemd credentials:

```nix
services.freepbx.database.passwordFile = config.age.secrets.freepbx-db.path;
```

---

## `services.freepbx.adminPasswordFile`

**Type:** `null or path`  
**Default:** `null`

Path to a file containing the FreePBX web admin password. If set,
`freepbx-init` calls `fwconsole userman --reset-admin-password` on first boot.

```nix
services.freepbx.adminPasswordFile = config.age.secrets.freepbx-admin.path;
```

---

## `services.freepbx.openFirewall`

**Type:** `bool`  
**Default:** `false`

When `true`, opens the following ports in `networking.firewall`:

| Protocol | Ports |
|---|---|
| UDP | `sipPort` (default 5060) |
| TCP | `sipPort`, `tlsSipPort` (5060, 5061), 80, 443 |
| UDP | `rtpPortRange.from` – `rtpPortRange.to` (10000–20000) |

---

## `services.freepbx.sipPort`

**Type:** `port` (0–65535)  
**Default:** `5060`

SIP signaling port for UDP and TCP. Standard IANA-assigned SIP port.

---

## `services.freepbx.tlsSipPort`

**Type:** `port` (0–65535)  
**Default:** `5061`

SIP TLS signaling port. Used when PJSIP transport is configured for TLS.

---

## `services.freepbx.rtpPortRange.from`

**Type:** `port` (0–65535)  
**Default:** `10000`

First UDP port in the RTP media port range. Must be less than `rtpPortRange.to`.

---

## `services.freepbx.rtpPortRange.to`

**Type:** `port` (0–65535)  
**Default:** `20000`

Last UDP port in the RTP media port range.

---

## `services.freepbx.extraConfig`

**Type:** `lines`  
**Default:** `""`

Extra PHP lines appended verbatim to `/etc/freepbx.conf`. Use for
`$amp_conf` keys not exposed as first-class options:

```nix
services.freepbx.extraConfig = ''
  $amp_conf['AMPDISABLELOG'] = 'false';
  $amp_conf['AMPASTERISKCONFDIR'] = '/etc/asterisk';
  $amp_conf['FPBXDBENGINE'] = 'mysql';
'';
```
