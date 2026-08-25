{
  description = "FreePBX — open-source Asterisk PBX management GUI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { inherit system; };
          freepbx-update = pkgs.writeShellApplication {
            name = "freepbx-update";
            runtimeInputs = [ pkgs.jq ];
            text = builtins.replaceStrings
              [ "#!/usr/bin/env bash\n" ]
              [ "" ]
              (builtins.readFile ./pkgs/freepbx/update.sh);
          };
        in
        {
          packages = {
            freepbx = pkgs.callPackage ./pkgs/freepbx { };
            inherit freepbx-update;
            default = self.packages.${system}.freepbx;
          };

          apps.update = {
            type = "app";
            program = "${freepbx-update}/bin/freepbx-update";
            meta = with pkgs.lib; {
              description = "Refresh pinned FreePBX framework and module source hashes";
              license = licenses.mit;
              mainProgram = "freepbx-update";
            };
          };

          checks = {
            basic = import ./tests/basic.nix { inherit pkgs; };
            firewall = import ./tests/firewall.nix { inherit pkgs; };
            cron = import ./tests/cron.nix { inherit pkgs; };
            upgrade = import ./tests/upgrade.nix { inherit pkgs; };
            database = import ./tests/database.nix { inherit pkgs; };
            module-options = import ./tests/module-options.nix { inherit pkgs; };
            update-script = pkgs.runCommand "freepbx-update-script-check"
              {
                nativeBuildInputs = [ pkgs.shellcheck ];
                src = ./pkgs/freepbx/update.sh;
              }
              ''
                shellcheck "$src"
                bash -n "$src"
                touch $out
              '';
          };

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nix-update
              nixpkgs-fmt
              statix
              deadnix
              freepbx-update
            ];
            shellHook = ''
              echo "FreePBX Nix dev shell"
              echo "  nix build .#freepbx       — build the package"
              echo "  nix flake check           — run lints + VM test"
              echo "  freepbx-update            — refresh source/module hashes"
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

      overlays.default = _: prev: {
        freepbx = self.packages.${prev.system}.freepbx;
      };
    };
}
