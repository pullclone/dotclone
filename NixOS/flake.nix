{
  description = "NyxOS — Framework 13 AMD (Strix Point) • NixOS 25.11 + Niri";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/30a3c519afcf3f99e2c6df3b359aec5692054d92";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/fb7944c166a3b630f177938e478f0378e64ce108";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
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

    mkNyx = { zramModule ? ./modules/zram-lz4.nix
           , latencyflexEnable ? true
           }:
      lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs pkgsUnstable stylix;
        };
        modules = [
          (import zramModule)

          ./configuration.nix
          niri.nixosModules.niri

          ./modules/latencyflex-module.nix
          { my.performance.latencyflex.enable = latencyflexEnable; }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs pkgsUnstable stylix;
            };
            home-manager.users.ashy = import ./home-ashy.nix;
          }
        ];
      };
  in {
    nixosConfigurations = {
      nyx                = mkNyx { zramModule = ./modules/zram-lz4.nix;           latencyflexEnable = true;  };
      nyx-lfx-off        = mkNyx { zramModule = ./modules/zram-lz4.nix;           latencyflexEnable = false; };

      nyx-zstdb-lfx      = mkNyx { zramModule = ./modules/zram-zstd-balanced.nix; latencyflexEnable = true;  };
      nyx-zstdb-lfx-off  = mkNyx { zramModule = ./modules/zram-zstd-balanced.nix; latencyflexEnable = false; };

      nyx-zstda-lfx      = mkNyx { zramModule = ./modules/zram-zstd-aggressive.nix; latencyflexEnable = true;  };
      nyx-zstda-lfx-off  = mkNyx { zramModule = ./modules/zram-zstd-aggressive.nix; latencyflexEnable = false; };

      nyx-zstdwb-lfx     = mkNyx { zramModule = ./modules/zram-writeback.nix;     latencyflexEnable = true;  };
      nyx-zstdwb-lfx-off = mkNyx { zramModule = ./modules/zram-writeback.nix;     latencyflexEnable = false; };

      # Optional aliases (ZRAM-only names)
      nyx-zstd-balanced   = mkNyx { zramModule = ./modules/zram-zstd-balanced.nix; };
      nyx-zstd-aggressive = mkNyx { zramModule = ./modules/zram-zstd-aggressive.nix; };
      nyx-writeback       = mkNyx { zramModule = ./modules/zram-writeback.nix; };
    };
  };
}
