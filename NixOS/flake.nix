{
  description = "NixOS + Niri + Noctalia + Unified Shells";

  inputs = {
    # System Packages (Stable 25.11)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Unstable (Required for Noctalia & bleeding edge Niri components)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Niri Flake
    niri.url = "github:sodiboo/niri-flake";

    # Stylix (Theming)
    stylix.url = "github:danth/stylix";

    # Noctalia (Official)
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, niri, stylix, noctalia, ... }@inputs:
    let
      system = "x86_64-linux";
      # Create an unstable package set to pass to modules
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.nyx = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgsUnstable stylix; };
        modules = [
          ./configuration.nix

          # System-level modules
          niri.nixosModules.niri
          stylix.nixosModules.stylix

          # --- ZRAM SELECTION ---
          ./modules/zram-lz4.nix
          # ./modules/zram-zstd-balanced.nix
          # ./modules/zram-zstd-aggressive.nix
          # ./modules/zram-writeback.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs pkgsUnstable stylix; };
            home-manager.users.ashy = import ./home-ashy.nix;
          }
          {
            nixpkgs.overlays = [ (self: super: { stylix = stylix.lib; }) ];
          }


        ];
      };

      # ISO output using the correct method
      packages.${system}.iso = let
        pkgs = nixpkgs.legacyPackages.${system};
        iso = pkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ({ config, pkgs, ... }: {
              # Basic ISO configuration without conflicts
              boot.loader.grub.efiSupport = true;
              boot.loader.grub.efiInstallAsRemovable = true;
              boot.supportedFilesystems = [ "btrfs" "ext4" "f2fs" "xfs" "ntfs" ];
              
              # Networking for installer
              networking.hostName = "nixos-installer";
              networking.networkmanager.enable = true;
              
              # Enable SSH for remote installation
              services.openssh.enable = true;
              services.openssh.permitRootLogin = "yes";
              
              # Set root password
              users.users.root.password = "root";
              
              # Basic services
              services.ntp.enable = true;
              
              # Include some optimizations that don't conflict
              boot.kernel.sysctl = {
                "vm.swappiness" = 10;
                "net.ipv4.tcp_congestion_control" = "bbr";
              };
            })
          ];
        };
      in nixpkgs.writeIsoImage {
        name = "nyxos-installer";
        contents = [
          (pkgs.writeText "iso-config" ""
            #!/bin/bash
            # This will be used during installation
            echo "NyxOS Installer"
          "")
        ];
        isoImage = iso.config.system.build.isoImage;
      };
    };
}
