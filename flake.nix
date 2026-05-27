{
  description = "FreePBX — open-source Asterisk PBX management GUI";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages = {
          freepbx = pkgs.callPackage ./pkgs/freepbx { };
          default = self.packages.${system}.freepbx;
        };

        checks = {
          basic          = import ./tests/basic.nix          { inherit pkgs; };
          firewall       = import ./tests/firewall.nix       { inherit pkgs; };
          cron           = import ./tests/cron.nix           { inherit pkgs; };
          upgrade        = import ./tests/upgrade.nix        { inherit pkgs; };
          database       = import ./tests/database.nix       { inherit pkgs; };
          module-options = import ./tests/module-options.nix { inherit pkgs; };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix-update
            nixpkgs-fmt
            statix
            deadnix
          ];
          shellHook = ''
            echo "FreePBX Nix dev shell"
            echo "  nix build .#freepbx       — build the package"
            echo "  nix flake check           — run lints + VM test"
            echo "  nixpkgs-fmt **/*.nix      — format Nix files"
            echo "  statix check .            — static analysis"
            echo "  deadnix --edit **/*.nix   — remove dead code"
          '';
        };
      }
    ) // {
      nixosModules = {
        # The module applies the flake's overlay so pkgs.freepbx resolves,
        # and sets the package default. Users can still override it.
        freepbx = { pkgs, ... }: {
          imports = [ ./nixos/modules/freepbx.nix ];
          nixpkgs.overlays = [ self.overlays.default ];
          services.freepbx.package = pkgs.lib.mkDefault pkgs.freepbx;
        };
        default = self.nixosModules.freepbx;
      };

      overlays.default = final: prev: {
        freepbx = self.packages.${prev.system}.freepbx;
      };
    };
}
