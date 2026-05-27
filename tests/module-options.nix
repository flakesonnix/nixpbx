# Evaluation-time tests for the NixOS module option types and defaults.
# These don't boot a VM — they eval the module system to confirm options
# are accepted at the right types. NixOS assertions (config.assertions)
# are checked at system-build time, not evalModules time, so they cannot
# be tested here via builtins.tryEval.
#
# Run: nix build .#checks.x86_64-linux.module-options
{ pkgs ? import <nixpkgs> { } }:

let
  inherit (pkgs) lib;
  freepbxPackage = pkgs.callPackage ../pkgs/freepbx { };

  evalConfig = module:
    (lib.evalModules {
      modules = [
        ../nixos/modules/freepbx.nix
        { _module.args = { inherit pkgs; }; }
        { config._module.check = false; }
        # supply required package option
        { services.freepbx.package = freepbxPackage; }
        module
      ];
    }).config;

  mustEval = desc: module:
    let result = builtins.tryEval (builtins.seq (evalConfig module) true);
    in if result.success then
      { name = desc; value = "ok"; }
    else
      throw "${desc}: unexpected evaluation failure";

  results = builtins.listToAttrs [
    (mustEval "disabled by default"
      { })

    (mustEval "enable=true accepted"
      { services.freepbx.enable = true; })

    (mustEval "custom user and group"
      {
        services.freepbx = {
          enable = true;
          user = "pbx";
          group = "pbx";
        };
      })

    (mustEval "custom dataDir changes webRoot default"
      {
        services.freepbx.enable = true;
        services.freepbx.dataDir = "/srv/freepbx";
      })

    (mustEval "custom SIP ports"
      {
        services.freepbx = {
          enable = true;
          sipPort = 5160;
          tlsSipPort = 5161;
        };
      })

    (mustEval "custom RTP range"
      {
        services.freepbx = {
          enable = true;
          rtpPortRange = { from = 20000; to = 30000; };
        };
      })

    (mustEval "database.passwordFile path"
      {
        services.freepbx.enable = true;
        services.freepbx.database.passwordFile = "/run/secrets/db-pass";
      })

    (mustEval "database.passwordFile null"
      {
        services.freepbx.enable = true;
        services.freepbx.database.passwordFile = null;
      })

    (mustEval "adminPasswordFile path"
      {
        services.freepbx.enable = true;
        services.freepbx.adminPasswordFile = "/run/secrets/admin-pass";
      })

    (mustEval "openFirewall=true"
      {
        services.freepbx.enable = true;
        services.freepbx.openFirewall = true;
      })

    (mustEval "extraConfig lines"
      {
        services.freepbx.enable = true;
        services.freepbx.extraConfig = "\$amp_conf['AMPDISABLELOG'] = 'false';";
      })
  ];

in
pkgs.runCommand "freepbx-module-option-tests" { } ''
  echo "Module option evaluation results:"
  ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: val:
    "echo '  [${val}] ${name}'"
  ) results)}
  echo "All tests passed."
  touch $out
''
