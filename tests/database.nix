# VM test: MariaDB is provisioned with the correct database and user.
{ pkgs ? import <nixpkgs> {} }:

pkgs.nixosTest {
  name = "freepbx-database";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable = true;
      database = {
        name         = "asterisk";
        user         = "asterisk";
        passwordFile = pkgs.writeText "db-pass" "hunter2";
      };
    };

    virtualisation.memorySize = 1024;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("mysql.service", timeout=120)

    # Database exists
    machine.succeed(
      "mysql -u root -e 'SHOW DATABASES;' | grep -q 'asterisk'"
    )

    # User has been created
    machine.succeed(
      "mysql -u root -e \"SELECT User FROM mysql.user;\" | grep -q 'asterisk'"
    )

    # User can connect with the password from the file
    machine.succeed(
      "mysql -u asterisk -phunter2 asterisk -e 'SELECT 1;'"
    )

    # freepbx.conf was written and contains the DB config
    machine.wait_for_unit("freepbx-init.service", timeout=180)
    machine.succeed("grep -q 'asterisk' /etc/freepbx.conf")
    machine.succeed("grep -q 'AMPDBPASS' /etc/freepbx.conf")

    # freepbx.conf has restrictive permissions
    machine.succeed("stat -c '%a' /etc/freepbx.conf | grep -q '640'")
  '';
}
