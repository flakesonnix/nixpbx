# Example: run FreePBX inside a microvm.nix lightweight VM.
#
# microvm.nix uses KVM (kvmgt/cloud-hypervisor/qemu) instead of a full
# NixOS VM. Much faster boot, lower memory overhead than a traditional VM.
#
# Prerequisites on the host:
#   - KVM available (/dev/kvm)
#   - microvm host NixOS module enabled (see host-config.nix below)
#
# Deploy:
#   nix run .#nixosConfigurations.freepbx-vm.config.microvm.declaredRunner
#
# Or register with the microvm host service so it starts on boot:
#   nixos-rebuild switch  (with host-config.nix imported)
{
  description = "FreePBX microvm example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
    nixpbx.url = "github:flakesonnix/nixpbx";
    nixpbx.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, microvm, nixpbx, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.freepbx-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # microvm guest module
          microvm.nixosModules.microvm

          # FreePBX module (brings in the overlay so pkgs.freepbx resolves)
          nixpbx.nixosModules.freepbx

          {
            # ── microvm settings ──────────────────────────────────────────
            microvm = {
              # Hypervisor: cloud-hypervisor is fastest; qemu most compatible.
              # Options: "qemu" | "cloud-hypervisor" | "kvmgt" | "firecracker"
              hypervisor = "cloud-hypervisor";

              mem = 2048; # MiB RAM
              vcpu = 2;

              # Writable overlay for /var — FreePBX state survives reboots.
              # The host path must exist before the VM starts.
              volumes = [
                {
                  mountPoint = "/var";
                  image = "freepbx-var.img";
                  size = 10240; # MiB
                }
              ];

              # Expose SIP and HTTP to the host network via TAP interface.
              # Adjust MAC and host bridge name to match your setup.
              interfaces = [
                {
                  type = "tap";
                  id = "vm-freepbx";
                  mac = "02:00:00:00:01:01";
                }
              ];

              shares = [
                {
                  # Mount the Nix store from the host — avoids duplicating
                  # store paths inside the VM image.
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                }
              ];
            };

            # ── FreePBX service ───────────────────────────────────────────
            services.freepbx = {
              enable = true;
              dataDir = "/var/lib/freepbx";

              database.passwordFile = "/run/secrets/freepbx-db-pass";
              adminPasswordFile = "/run/secrets/freepbx-admin-pass";

              openFirewall = true;
              sipPort = 5060;
              tlsSipPort = 5061;
              rtpPortRange = { from = 10000; to = 20000; };
            };

            # ── secrets (use agenix, sops-nix, or systemd-creds) ─────────
            # Example with systemd credentials (no extra flake needed):
            systemd.services.freepbx-init.serviceConfig.LoadCredential = [
              "freepbx-db-pass:/etc/nixos/secrets/freepbx-db-pass"
              "freepbx-admin-pass:/etc/nixos/secrets/freepbx-admin-pass"
            ];
            services.freepbx.database.passwordFile =
              "/run/credentials/freepbx-init.service/freepbx-db-pass";
            services.freepbx.adminPasswordFile =
              "/run/credentials/freepbx-init.service/freepbx-admin-pass";

            # ── minimal guest OS ──────────────────────────────────────────
            system.stateVersion = "25.05";

            # No GUI needed
            services.xserver.enable = false;

            # Networking inside the VM — static IP on the TAP interface.
            # Adjust to match your host bridge subnet.
            networking = {
              hostName = "freepbx-vm";
              interfaces.eth0.ipv4.addresses = [
                { address = "192.168.100.10"; prefixLength = 24; }
              ];
              defaultGateway = "192.168.100.1";
              nameservers = [ "1.1.1.1" ];
              firewall.enable = true;
            };
          }
        ];
      };
    };
}
