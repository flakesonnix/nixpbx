# VM test: verify firewall rules are applied when openFirewall = true,
# and absent when openFirewall = false (the default).
{ pkgs ? import <nixpkgs> { } }:

let
  freepbxPackage = pkgs.callPackage ../pkgs/freepbx { };
  dbPass = pkgs.writeText "db-pass" "test";
in
pkgs.testers.nixosTest {
  name = "freepbx-firewall";

  nodes = {
    server = { ... }: {
      imports = [ ../nixos/modules/freepbx.nix ];
      services.freepbx = {
        enable = true;
        package = freepbxPackage;
        openFirewall = true;
        sipPort = 5060;
        tlsSipPort = 5061;
        rtpPortRange = { from = 10000; to = 10010; };
        database.passwordFile = dbPass;
      };
      virtualisation.memorySize = 1024;
    };

    serverClosed = { ... }: {
      imports = [ ../nixos/modules/freepbx.nix ];
      services.freepbx = {
        enable = true;
        package = freepbxPackage;
        openFirewall = false;
        database.passwordFile = dbPass;
      };
      virtualisation.memorySize = 1024;
    };
  };

  testScript = ''
    server.start()
    serverClosed.start()
    server.wait_for_unit("multi-user.target")
    serverClosed.wait_for_unit("multi-user.target")

    server.succeed("iptables -L INPUT -n | grep -q '5060'")
    server.succeed("iptables -L INPUT -n | grep -q '5061'")
    server.succeed(
      "iptables -L INPUT -n | grep -qE '10000.*10010|udp dpt:10000:10010'"
    )
    server.succeed("iptables -L INPUT -n | grep -q 'dpt:80'")
    server.succeed("iptables -L INPUT -n | grep -q 'dpt:443'")
    serverClosed.fail("iptables -L INPUT -n | grep -q 'dpt:5060'")
  '';
}
