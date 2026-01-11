{
  description = "NyxOS — Framework 13 AMD (Strix Point) • NixOS 25.11 + Niri";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/30a3c519afcf3f99e2c6df3b359aec5692054d92";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/fb7944c166a3b630f177938e478f0378e64ce108";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Added Lanzaboote for Secure Boot support
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";
    niri.url = "github:sodiboo/niri-flake";

    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, stylix, niri, noctalia, ... }@inputs:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;

    pkgsUnstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    mkNyx =
      { zramModule ? ./modules/tuning/zram/zram-lz4.nix
      , latencyflexEnable ? true
      }:
      lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs pkgsUnstable stylix;
        };

        modules = [
          # 1. ZRAM Profile (Argument)
          zramModule

          # 2. Boot Profile (The Switch)
          ./modules/boot/boot-profile.nix
          {
            # Default state: Standard UKI-ready boot.
            # To enable Secure Boot later: set uki=false, secureBoot=true.
            my.boot.uki.enable = true;
            my.boot.secureBoot.enable = false;
          }

          # 3. Installation Facts
          ./modules/core/install-answers.nix

          # 4. Domain Modules (Hardware & Tuning)
          ./modules/hardware/amd-gpu.nix
          ./modules/tuning/sysctl.nix

          # 5. Main Policy Configuration
          ./configuration.nix

          # 6. Desktop & Features
          niri.nixosModules.niri
          ./modules/programs/latencyflex-module.nix
          { my.performance.latencyflex.enable = latencyflexEnable; }

          # 7. Writeback Configuration (Default: Disabled)
          (import ./modules/tuning/zram/zram-writeback.nix)
          {
             my.swap.writeback.enable = false;
             my.swap.writeback.device = null;
          }

          # 8. Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs pkgsUnstable stylix system;
            };
            home-manager.users.ashy = import ./modules/home/home-ashy.nix;
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      nyx                 = mkNyx { zramModule = ./modules/tuning/zram/zram-lz4.nix;            latencyflexEnable = true; };
      nyx-lfx-off         = mkNyx { zramModule = ./modules/tuning/zram/zram-lz4.nix;            latencyflexEnable = false; };

      # ZRAM Writeback Enabled Variants
      nyx-writeback       = mkNyx {
          zramModule = ./modules/tuning/zram/zram-writeback.nix;
          latencyflexEnable = true;
      };
    };
  };
}
