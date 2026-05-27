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
          basic = import ./tests/basic.nix { inherit pkgs; };
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
        freepbx = import ./nixos/modules/freepbx.nix;
        default = self.nixosModules.freepbx;
      };

      overlays.default = final: prev: {
        freepbx = self.packages.${prev.system}.freepbx;
      };
    };
}
