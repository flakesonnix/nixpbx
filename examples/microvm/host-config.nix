# Import this into your HOST NixOS configuration to:
#   1. Enable the microvm host service (manages VM lifecycle)
#   2. Register the freepbx-vm as a declared microvm
#
# Your host flake.nix inputs need:
#   microvm.url = "github:astro/microvm.nix";
#
# Then in your host nixosSystem modules list:
#   ./host-config.nix
{ inputs, ... }:
{
  imports = [ inputs.microvm.nixosModules.host ];

  microvm.vms.freepbx-vm = {
    # Point at the guest flake defined in examples/microvm/flake.nix
    flake = inputs.self;
    # Auto-start on host boot and restart on failure
    autostart = true;
  };

  # Create the TAP bridge the VM connects to
  networking = {
    bridges.br-freepbx.interfaces = [ ];
    interfaces.br-freepbx.ipv4.addresses = [
      { address = "192.168.100.1"; prefixLength = 24; }
    ];
    # Optional: NAT so the VM can reach the internet via the host
    nat = {
      enable = true;
      internalInterfaces = [ "br-freepbx" ];
      externalInterface = "eth0"; # replace with your host's WAN interface
    };
  };

  # Allow the host to forward packets to/from the VM
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
