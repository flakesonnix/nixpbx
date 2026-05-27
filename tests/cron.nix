# VM test: freepbx-cron.timer fires and freepbx-cron.service completes.
{ pkgs ? import <nixpkgs> { } }:

let
  freepbxPackage = pkgs.callPackage ../pkgs/freepbx { };
in
pkgs.testers.nixosTest {
  name = "freepbx-cron";

  nodes.machine = { lib, ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable = true;
      package = freepbxPackage;
      database.passwordFile = pkgs.writeText "db-pass" "test";
    };

    systemd.timers.freepbx-cron.timerConfig = lib.mkForce {
      OnCalendar = "*:0/1";
      Persistent = true;
    };

    virtualisation.memorySize = 2048;
    virtualisation.diskSize = 4096;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("freepbx-init.service", timeout=180)
    machine.succeed("systemctl is-active freepbx-cron.timer")
    machine.succeed("systemctl start freepbx-cron.service")
    machine.succeed(
      "systemctl show freepbx-cron.service --property=Result | grep 'Result=success'"
    )
  '';
}
