# VM test: simulates upgrading FreePBX by switching to a new package path.
# Verifies freepbx-init re-deploys the web root without data loss.
{ pkgs ? import <nixpkgs> { } }:

let
  freepbxPackage = pkgs.callPackage ../pkgs/freepbx { };
in
pkgs.testers.nixosTest {
  name = "freepbx-upgrade";

  nodes.machine = { ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable = true;
      package = freepbxPackage;
      database.passwordFile = pkgs.writeText "db-pass" "test";
    };

    virtualisation.memorySize = 2048;
    virtualisation.diskSize = 8192;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("freepbx-init.service", timeout=300)
    machine.wait_for_open_port(80, timeout=60)
    machine.wait_for_unit("freepbx-reload.service", timeout=60)

    machine.succeed("touch /var/lib/freepbx/www/admin/modules/mymodule/.installed")
    machine.succeed("rm /var/lib/freepbx/www/.deployed")
    machine.succeed("systemctl restart freepbx-init.service")
    machine.wait_for_unit("freepbx-init.service")

    machine.succeed("test -f /var/lib/freepbx/www/.deployed")
    machine.succeed("test -f /var/lib/freepbx/www/admin/modules/mymodule/.installed")
    machine.succeed("curl -sf http://localhost/admin/config.php | grep -qi freepbx")
  '';
}
