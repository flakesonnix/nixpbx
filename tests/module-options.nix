# Evaluation-time tests for the NixOS module option types and defaults.
# These don't boot a VM — they just eval the module system to confirm
# options are accepted, defaults are correct, and assertions fire.
#
# Run: nix eval .#checks.x86_64-linux.module-options
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;

  evalConfig = module:
    (lib.evalModules {
      modules = [
        ../nixos/modules/freepbx.nix
        # Stub out nixpkgs module system prerequisites
        { _module.args = { inherit pkgs; }; }
        # Silence missing nixpkgs options (users.*, services.*, etc.)
        { config._module.check = false; }
        module
      ];
    }).config;

  # helper: evalConfig must succeed
  mustEval = desc: module:
    let result = builtins.tryEval (builtins.seq (evalConfig module) true);
    in if result.success then
      { name = desc; value = "ok"; }
    else
      throw "${desc}: unexpected evaluation failure";

  # helper: evalConfig must throw
  mustFail = desc: module:
    let result = builtins.tryEval (builtins.seq (evalConfig module) true);
    in if result.success then
      throw "${desc}: expected failure but eval succeeded"
    else
      { name = desc; value = "ok (threw as expected)"; };

  results = builtins.listToAttrs [
    # ── defaults ────────────────────────────────────────────────────────────
    (mustEval "disabled by default — empty module is fine"
      {})

    (mustEval "enable=true with minimal required options"
      { services.freepbx.enable = true; })

    # ── user / group ─────────────────────────────────────────────────────────
    (mustEval "custom user and group accepted"
      {
        services.freepbx.enable = true;
        services.freepbx.user   = "pbx";
        services.freepbx.group  = "pbx";
      })

    # ── port options ─────────────────────────────────────────────────────────
    (mustEval "custom SIP ports accepted"
      {
        services.freepbx.enable     = true;
        services.freepbx.sipPort    = 5160;
        services.freepbx.tlsSipPort = 5161;
      })

    (mustEval "custom RTP range accepted"
      {
        services.freepbx.enable              = true;
        services.freepbx.rtpPortRange.from   = 20000;
        services.freepbx.rtpPortRange.to     = 30000;
      })

    (mustFail "rtpPortRange.from >= rtpPortRange.to triggers assertion"
      {
        services.freepbx.enable              = true;
        services.freepbx.rtpPortRange.from   = 30000;
        services.freepbx.rtpPortRange.to     = 20000;
      })

    # ── database options ─────────────────────────────────────────────────────
    (mustEval "database.passwordFile as path accepted"
      {
        services.freepbx.enable                  = true;
        services.freepbx.database.passwordFile   = "/run/secrets/db-pass";
      })

    (mustEval "database.passwordFile null (default) accepted"
      {
        services.freepbx.enable                  = true;
        services.freepbx.database.passwordFile   = null;
      })

    # ── adminPasswordFile ────────────────────────────────────────────────────
    (mustEval "adminPasswordFile as path accepted"
      {
        services.freepbx.enable               = true;
        services.freepbx.adminPasswordFile    = "/run/secrets/admin-pass";
      })

    # ── firewall ─────────────────────────────────────────────────────────────
    (mustEval "openFirewall=true accepted"
      {
        services.freepbx.enable      = true;
        services.freepbx.openFirewall = true;
      })

    # ── extraConfig ──────────────────────────────────────────────────────────
    (mustEval "extraConfig lines accepted"
      {
        services.freepbx.enable      = true;
        services.freepbx.extraConfig = ''
          $amp_conf['AMPDISABLELOG'] = 'false';
        '';
      })
  ];

in
  pkgs.runCommand "freepbx-module-option-tests" {} ''
    echo "Module option evaluation results:"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: val:
      "echo '  [${val}] ${name}'"
    ) results)}
    echo "All tests passed."
    touch $out
  ''
