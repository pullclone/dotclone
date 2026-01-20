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

    # Profile framework (system + zram)
    profiles.url = "path:./profiles";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      stylix,
      niri,
      noctalia,
      profiles,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      latencyflexOverlay = import ./overlays/latencyflex.nix;

      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      officialProfiles = [
        "latency"
        "balanced"
        "throughput"
        "battery"
        "memory-saver"
      ];
      availableProfiles = builtins.attrNames inputs.profiles.nyxProfiles.system;

      _ = lib.assertMsg (lib.all (p: lib.elem p availableProfiles) officialProfiles) ''
        NyxOS: officialProfiles contains a profile not provided by profiles flake.
        officialProfiles=${lib.concatStringsSep ", " officialProfiles}
        available=${lib.concatStringsSep ", " availableProfiles}
      '';

      mkNyx =
        {
          systemProfile ? "balanced",
          latencyflexEnable ? true,
        }:
        let
          _ = lib.assertMsg (lib.elem systemProfile officialProfiles) ''
            NyxOS: invalid systemProfile '${systemProfile}'. Official profiles: ${lib.concatStringsSep ", " officialProfiles}
          '';
          chosenSystemProfile = inputs.profiles.nyxProfiles.system.${systemProfile};
        in
        lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit
              inputs
              pkgsUnstable
              stylix
              systemProfile
              ;
          };

          modules = [
            # 0. Overlays
            { nixpkgs.overlays = [ latencyflexOverlay ]; }

            # 1. System Profile (Argument) - includes ZRAM + tuning
            chosenSystemProfile

            # 2. Boot Profile (The Switch)
            ./modules/boot/boot-profile.nix
            {
              # Default state: Standard UKI-ready boot.
              # To enable Secure Boot later: set uki=false, secureBoot=true.
              my.boot.uki.enable = true;
              my.boot.secureBoot.enable = false;
            }
            ./modules/boot/uki.nix

            # 3. Installation Facts
            ./modules/core/install-answers.nix

            # 4. Domain Modules (Hardware & Tuning)
            ./modules/hardware/amd-gpu.nix
            ./modules/hardware/nvidia-gpu.nix
            ./modules/tuning/sysctl.nix
            (inputs.nixpkgs.outPath + "/nixos/modules/services/backup/btrbk.nix")
            ./modules/tuning/btrfs-snapshots.nix
            ./modules/security/phase.nix
            ./modules/security/access.nix
            ./modules/security/locker-pam.nix
            ./modules/security/time-sync.nix
            ./modules/security/systemd-hardening.nix
            ./modules/security/usbguard.nix
            ./modules/security/u2f.nix

            # 5. Main Policy Configuration
            ./configuration.nix

            # 6. Desktop & Features
            niri.nixosModules.niri
            ./modules/programs/latencyflex-module.nix
            ./modules/programs/containers.nix
            { my.performance.latencyflex.enable = latencyflexEnable; }

            # 7. Home Manager
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit
                  inputs
                  pkgsUnstable
                  stylix
                  system
                  ;
              };
              home-manager.users.ashy = import ./modules/home/home-ashy.nix;
            }
          ];
        };
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;

      packages.${system} =
        let
          mkToplevel =
            profile: latencyflexEnable:
            let
              suffix = if latencyflexEnable then "on" else "off";
              name = "nyx-${profile}-lfx-${suffix}";
            in
            {
              inherit name;
              value = self.nixosConfigurations.${name}.config.system.build.toplevel;
            };

          toplevelAttrs = lib.listToAttrs (
            lib.flatten (
              map (profile: [
                (mkToplevel profile true)
                (mkToplevel profile false)
              ]) officialProfiles
            )
            ++ [
              {
                name = "toplevel-nyx";
                value = self.nixosConfigurations.nyx.config.system.build.toplevel;
              }
            ]
          );
        in
        {
          nixfmt = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
          statix = nixpkgs.legacyPackages.${system}.statix;
          deadnix = nixpkgs.legacyPackages.${system}.deadnix;
        }
        // toplevelAttrs;

      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = with nixpkgs.legacyPackages.${system}; [
          just
          git
          ripgrep
          shellcheck
          shfmt
          nixfmt-rfc-style
          statix
          deadnix
        ];
      };

      nixosConfigurations = lib.listToAttrs (
        [
          {
            name = "nyx";
            value = mkNyx {
              systemProfile = "balanced";
              latencyflexEnable = true;
            };
          }
        ]
        ++ lib.flatten (
          map (profile: [
            {
              name = "nyx-${profile}-lfx-on";
              value = mkNyx {
                systemProfile = profile;
                latencyflexEnable = true;
              };
            }
            {
              name = "nyx-${profile}-lfx-off";
              value = mkNyx {
                systemProfile = profile;
                latencyflexEnable = false;
              };
            }
          ]) officialProfiles
        )
      );
    };
}
