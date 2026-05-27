# nixpbx

Nix flake packaging FreePBX 17 for NixOS, following nixpkgs conventions.

## Usage

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
          services.freepbx.openFirewall = true;
        }
      ];
    };
  };
}
```

```bash
sudo nixos-rebuild switch --flake .#myserver
```

## Commands

```bash
nix build .#freepbx          # build the package
nix flake check              # lint + VM integration test
nix develop                  # dev shell with nix-update, statix, deadnix
```

## Docs

- [User guide](doc/freepbx.md)
- [Options reference](doc/options.md)

## Status

SHA-256 hashes for upstream GitHub sources are placeholders (`sha256-AAAA...`).
Run `nix build .#freepbx` and fill in the hashes printed by Nix before deploying.

## License

Packaging: MIT. FreePBX framework: AGPL v3. FreePBX modules: GPL v3.
