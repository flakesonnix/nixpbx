{ pkgs ? import <nixpkgs> {} }:

pkgs.nixosTest {
  name = "freepbx-basic";

  meta.maintainers = [];

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable = true;
      database.passwordFile = pkgs.writeText "freepbx-test-db-pass" "testpassword123";
      openFirewall = true;
    };

    # Expose FreePBX package for test assertions
    environment.systemPackages = [ config.services.freepbx.package ];

    virtualisation.memorySize = 2048;
    virtualisation.diskSize   = 8192;

    # Speed up boot — no GUI
    services.xserver.enable = false;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("mysql.service", timeout=120)
    machine.wait_for_unit("freepbx-init.service", timeout=180)
    machine.wait_for_unit("httpd.service", timeout=60)
    machine.wait_for_unit("asterisk.service", timeout=60)
    machine.wait_for_open_port(80, timeout=60)

    # FreePBX admin UI responds
    machine.succeed("curl -sf http://localhost/admin/config.php | grep -qi freepbx")

    # fwconsole is reachable and reports a version
    machine.succeed("fwconsole --version")

    # Core services are running
    machine.succeed("systemctl is-active asterisk")
    machine.succeed("systemctl is-active mysql")
    machine.succeed("systemctl is-active freepbx-cron.timer")

    # freepbx.conf was written
    machine.succeed("test -f /etc/freepbx.conf")

    # Web root was deployed
    machine.succeed("test -f /var/lib/freepbx/www/.deployed")

    # Asterisk is accepting connections (AMI port)
    machine.wait_for_open_port(5038, timeout=30)
  '';
}
