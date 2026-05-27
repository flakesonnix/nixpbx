# nixpbx

A Nix flake that packages [FreePBX 17](https://www.freepbx.org) for NixOS.

> **Not affiliated with FreePBX or Sangoma Technologies.** This is an
> independent, community-maintained packaging effort. FreePBX source code
> is fetched directly from the official [FreePBX GitHub](https://github.com/FreePBX)
> repositories. Bugs in this packaging belong here. Bugs in FreePBX itself
> belong [upstream](https://github.com/FreePBX/framework/issues).

## What this gives you

- `packages.freepbx` — buildable with `nix build .#freepbx`
- `nixosModules.freepbx` — drop into any NixOS config, one enable line
- Full service wiring: MariaDB, Apache, PHP-FPM 8.2, Asterisk, systemd units
- Declarative firewall (SIP + RTP ports)
- Secret handling via file references — no passwords in the Nix store
- Six automated tests (VM integration + pure eval)

## Quick start

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpbx.url  = "github:flakesonnix/nixpbx";
    nixpbx.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpbx, ... }: {
    nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
      modules = [
        nixpbx.nixosModules.freepbx
        {
          services.freepbx.enable = true;
          services.freepbx.database.passwordFile = "/run/secrets/db-pass";
          services.freepbx.openFirewall = true;
        }
      ];
    };
  };
}
```

Then deploy:

```bash
sudo nixos-rebuild switch --flake .#myserver
```

FreePBX will be available at `http://<your-ip>/admin` after the first boot
completes (the `freepbx-init` service copies files and sets up the database).

## Running in a microVM

See [`examples/microvm/`](examples/microvm/) for a complete example using
[microvm.nix](https://github.com/astro/microvm.nix) — faster boot and lower
overhead than a traditional VM, backed by KVM.

## Commands

```bash
# Build the FreePBX package
nix build .#freepbx

# Run all checks (VM tests require KVM)
nix flake check

# Run just the fast eval test (no VM needed)
nix build .#checks.x86_64-linux.module-options

# Drop into a dev shell with formatting and lint tools
nix develop
```

## Configuration options

All options live under `services.freepbx`. Key ones:

| Option | Default | What it does |
|---|---|---|
| `enable` | `false` | Turn FreePBX on |
| `dataDir` | `/var/lib/freepbx` | Root for all writable state |
| `database.passwordFile` | `null` | Path to DB password file |
| `adminPasswordFile` | `null` | Path to web admin password file |
| `openFirewall` | `false` | Open SIP (5060/5061) + RTP ports |
| `sipPort` | `5060` | SIP signaling port |
| `rtpPortRange` | `10000–20000` | RTP media port range |
| `extraConfig` | `""` | Extra PHP lines in `freepbx.conf` |

Full reference: [`doc/options.md`](doc/options.md)

## Docs

- [User guide](doc/freepbx.md) — architecture, upgrade procedure, troubleshooting
- [Options reference](doc/options.md) — every `services.freepbx.*` option
- [Git workflow](doc/git-workflow.md) — branch model, commit conventions, hash updates

## Status

This packaging builds and passes `nix flake check`. VM tests (basic, firewall,
database, cron, upgrade) require KVM to run; they are not executed in CI by
default. Pull requests welcome.

## License

| Component | License |
|---|---|
| This packaging | MIT |
| FreePBX framework | AGPL v3 |
| FreePBX modules | GPL v3 |
