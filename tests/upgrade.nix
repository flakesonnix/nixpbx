# VM test: simulates upgrading FreePBX by switching to a new package path.
# Verifies freepbx-init re-deploys the web root without data loss.
{ pkgs ? import <nixpkgs> {} }:

pkgs.nixosTest {
  name = "freepbx-upgrade";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable = true;
      database.passwordFile = pkgs.writeText "db-pass" "test";
    };

    virtualisation.memorySize = 2048;
    virtualisation.diskSize   = 8192;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("freepbx-init.service", timeout=180)
    machine.wait_for_open_port(80, timeout=60)

    # Record the initial deployment marker
    initial_mtime = machine.succeed(
      "stat -c %Y /var/lib/freepbx/www/.deployed"
    ).strip()

    # Write a sentinel file to simulate user-installed module state
    machine.succeed("touch /var/lib/freepbx/www/admin/modules/mymodule/.installed")

    # Simulate package upgrade: remove .deployed marker to force re-deploy
    machine.succeed("rm /var/lib/freepbx/www/.deployed")
    machine.succeed("systemctl restart freepbx-init.service")
    machine.wait_for_unit("freepbx-init.service")

    # Deployment marker re-created
    machine.succeed("test -f /var/lib/freepbx/www/.deployed")

    # Sentinel NOT clobbered (cp -rT preserves existing files in target)
    # This is expected behavior: only new store files overwrite missing targets
    machine.succeed("test -f /var/lib/freepbx/www/admin/modules/mymodule/.installed")

    # Service still responds
    machine.succeed("curl -sf http://localhost/admin/config.php | grep -qi freepbx")
  '';
}
