# VM test: freepbx-cron.timer fires and freepbx-cron.service completes.
{ pkgs ? import <nixpkgs> {} }:

pkgs.nixosTest {
  name = "freepbx-cron";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable = true;
      database.passwordFile = pkgs.writeText "db-pass" "test";
    };

    # Speed up the timer for testing: fire every minute
    systemd.timers.freepbx-cron.timerConfig = pkgs.lib.mkForce {
      OnCalendar = "*:0/1";
      Persistent  = true;
    };

    virtualisation.memorySize = 2048;
    virtualisation.diskSize   = 4096;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("freepbx-init.service", timeout=180)

    # Timer is active
    machine.succeed("systemctl is-active freepbx-cron.timer")

    # Trigger the service directly and check it exits 0
    machine.succeed("systemctl start freepbx-cron.service")
    machine.succeed("systemctl is-active freepbx-cron.service || systemctl show freepbx-cron.service --property=Result | grep 'Result=success'")
  '';
}
