# VM test: MariaDB is provisioned with the correct database and user.
{ pkgs ? import <nixpkgs> { } }:

let
  freepbxPackage = pkgs.callPackage ../pkgs/freepbx { };
in
pkgs.testers.nixosTest {
  name = "freepbx-database";

  nodes.machine = { ... }: {
    imports = [ ../nixos/modules/freepbx.nix ];

    services.freepbx = {
      enable = true;
      package = freepbxPackage;
      database = {
        name = "asterisk";
        user = "asterisk";
        passwordFile = pkgs.writeText "db-pass" "hunter2";
      };
    };

    virtualisation.memorySize = 1024;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("mysql.service", timeout=120)

    machine.succeed("mysql -u root -e 'SHOW DATABASES;' | grep -q 'asterisk'")

    machine.wait_for_unit("freepbx-init.service", timeout=300)
    machine.succeed("grep -q 'asterisk' /etc/freepbx.conf")
    machine.succeed("grep -q 'AMPDBPASS' /etc/freepbx.conf")
    machine.succeed("stat -c '%a' /etc/freepbx.conf | grep -q '640'")

    # DB user created with password auth by freepbx-init
    machine.succeed(
      "mysql -u root -e \"SELECT User FROM mysql.user;\" | grep -q 'asterisk'"
    )
    machine.succeed("mysql -u asterisk -phunter2 asterisk -e 'SELECT 1;'")
    machine.succeed(
      "mysql -u root -e \"SHOW GRANTS FOR 'asterisk'@'localhost';\" | grep -q IDENTIFIED"
    )
  '';
}
