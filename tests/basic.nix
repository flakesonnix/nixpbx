{ pkgs ? import <nixpkgs> {} }:

let
  freepbxPackage = pkgs.callPackage ../pkgs/freepbx {};
in
pkgs.testers.nixosTest {
  name = "freepbx-basic";

  meta.maintainers = [];

  nodes.machine = { ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable   = true;
      package  = freepbxPackage;
      database.passwordFile = pkgs.writeText "freepbx-test-db-pass" "testpassword123";
      openFirewall = true;
    };

    services.xserver.enable = false;
    virtualisation.memorySize = 2048;
    virtualisation.diskSize   = 8192;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("mysql.service", timeout=120)
    machine.wait_for_unit("freepbx-init.service", timeout=180)
    machine.wait_for_unit("httpd.service", timeout=60)
    machine.wait_for_unit("asterisk.service", timeout=60)
    machine.wait_for_open_port(80, timeout=60)

    machine.succeed("curl -sf http://localhost/admin/config.php | grep -qi freepbx")
    machine.succeed("fwconsole --version")
    machine.succeed("systemctl is-active asterisk")
    machine.succeed("systemctl is-active mysql")
    machine.succeed("systemctl is-active freepbx-cron.timer")
    machine.succeed("test -f /etc/freepbx.conf")
    machine.succeed("test -f /var/lib/freepbx/www/.deployed")
    machine.wait_for_open_port(5038, timeout=30)
  '';
}
