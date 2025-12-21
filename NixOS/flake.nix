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
        specialArgs = { inherit inputs pkgsUnstable; };
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
            home-manager.extraSpecialArgs = { inherit inputs pkgsUnstable; };
            home-manager.users.ashy = import ./home-ashy.nix;
          }
        ];
      };
    };
}
