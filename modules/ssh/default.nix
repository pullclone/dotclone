{ config, lib, ... }:

let
  cfg = config.my.ssh;

  t = {
    client = {
      base = import ../../templates/ssh/client/base.nix;
      hardened = import ../../templates/ssh/client/hardened.nix;
      developer = import ../../templates/ssh/client/developer.nix;
      home = import ../../templates/ssh/client/home.nix;
      ci = import ../../templates/ssh/client/ci.nix;

      bastion = import ../../templates/ssh/client/bastion.nix;
      cloud = import ../../templates/ssh/client/cloud.nix;
      unreliable = import ../../templates/ssh/client/unreliable.nix;
      corporate = import ../../templates/ssh/client/corporate.nix;
      legacy = import ../../templates/ssh/client/legacy.nix;
    };

    server = {
      hardened = import ../../templates/ssh/server/hardened.nix;
    };
  };

  gitHostPins = import ../../templates/ssh/known-hosts/git-hosts.nix;

  emptyModule = { ... }: { };

  clientProfiles = {
    base = emptyModule;
    hardened = t.client.hardened;
    developer = t.client.developer;
    home = t.client.home;
    ci = t.client.ci;
  };

  clientFeatures = {
    "git-hosts" = emptyModule;
    bastion = t.client.bastion;
    cloud = t.client.cloud;
    unreliable = t.client.unreliable;
    corporate = t.client.corporate;
    legacy = t.client.legacy;
  };

  profileTemplate = profile: (lib.getAttr profile clientProfiles) { inherit lib; };

  featureTemplates =
    features: map (feature: (lib.getAttr feature clientFeatures) { inherit lib; }) features;

  mapPins =
    pins:
    lib.mapAttrs (host: publicKey: {
      hostNames = [ host ];
      inherit publicKey;
    }) pins;

  clientModule =
    { lib, ... }:
    {
      config = lib.mkMerge (
        [
          (t.client.base { inherit lib; })
          (profileTemplate cfg.client.profile)
          (lib.mkIf cfg.client.onePasswordAgent.enable {
            programs.ssh.extraConfig = lib.mkAfter ''
              IdentityAgent ~/.1password/agent.sock
            '';
          })
        ]
        ++ featureTemplates cfg.client.features
      );
    };
in
{
  options.my.ssh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable declarative SSH client/server configuration.";
    };

    client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH client profile management via Home Manager.";
      };

      profile = lib.mkOption {
        type = lib.types.enum [
          "base"
          "hardened"
          "developer"
          "home"
          "ci"
        ];
        default = "base";
        description = "SSH client profile to apply.";
      };

      features = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "git-hosts"
            "bastion"
            "cloud"
            "unreliable"
            "corporate"
            "legacy"
          ]
        );
        default = [ ];
        description = "Optional SSH feature bundles to layer on top of the client profile.";
      };

      onePasswordAgent.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable 1Password SSH agent integration.";
      };
    };

    server.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the hardened SSH server profile.";
    };

    knownHosts = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable system-wide SSH known_hosts policy (pins/CA).";
      };

      pins = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Pinned SSH known host keys (hostname -> public key).";
      };
    };

    cloud.caPublicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional SSH CA public key for cloud host certificates.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.client.enable {
        # HM owns client UX (matchBlocks, extraConfig, multiplexing).
        home-manager.sharedModules = [ clientModule ];
      })
      # NixOS owns trust roots (known_hosts pins / CA) and sshd policy.
      (lib.mkIf (cfg.knownHosts.enable && lib.elem "git-hosts" cfg.client.features) {
        programs.ssh.knownHosts = gitHostPins;
      })
      (lib.mkIf (cfg.knownHosts.enable && cfg.knownHosts.pins != { }) {
        programs.ssh.knownHosts = mapPins cfg.knownHosts.pins;
      })
      (lib.mkIf
        (cfg.knownHosts.enable && lib.elem "cloud" cfg.client.features && cfg.cloud.caPublicKey != null)
        {
          programs.ssh.knownHosts.awsCA = {
            hostNames = [ "@cert-authority *.compute.amazonaws.com" ];
            publicKey = cfg.cloud.caPublicKey;
          };
        }
      )
      (lib.mkIf cfg.server.enable (t.server.hardened { inherit lib; }))
      {
        warnings = lib.optionals (lib.elem "legacy" cfg.client.features) [
          "my.ssh.client.features contains \"legacy\"; use only as a last resort."
        ];
      }
    ]
  );
}
