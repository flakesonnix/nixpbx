# VM test: verify firewall rules are applied when openFirewall = true,
# and absent when openFirewall = false (the default).
{ pkgs ? import <nixpkgs> {} }:

pkgs.nixosTest {
  name = "freepbx-firewall";

  nodes = {
    # Server with firewall open
    server = { config, pkgs, ... }: {
      imports = [ ../nixos/modules/freepbx.nix ];
      services.freepbx = {
        enable       = true;
        openFirewall = true;
        sipPort      = 5060;
        tlsSipPort   = 5061;
        rtpPortRange = { from = 10000; to = 10010; };
        database.passwordFile = pkgs.writeText "db-pass" "test";
      };
      virtualisation.memorySize = 1024;
    };

    # Server with firewall closed (default)
    serverClosed = { config, pkgs, ... }: {
      imports = [ ../nixos/modules/freepbx.nix ];
      services.freepbx = {
        enable       = true;
        openFirewall = false;
        database.passwordFile = pkgs.writeText "db-pass" "test";
      };
      virtualisation.memorySize = 1024;
    };
  };

  testScript = ''
    server.start()
    serverClosed.start()
    server.wait_for_unit("multi-user.target")
    serverClosed.wait_for_unit("multi-user.target")

    # openFirewall = true: SIP port 5060 should be open in iptables
    server.succeed("iptables -L INPUT -n | grep -q '5060'")
    server.succeed("iptables -L INPUT -n | grep -q '5061'")

    # RTP range should appear
    server.succeed(
      "iptables -L INPUT -n | grep -qE '10000.*10010|udp dpt:10000:10010'"
    )

    # HTTP/HTTPS ports open
    server.succeed("iptables -L INPUT -n | grep -q 'dpt:80'")
    server.succeed("iptables -L INPUT -n | grep -q 'dpt:443'")

    # openFirewall = false: SIP port should NOT be open
    serverClosed.fail("iptables -L INPUT -n | grep -q 'dpt:5060'")
  '';
}
