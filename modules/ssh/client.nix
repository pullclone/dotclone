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
      cloudCaReady = import ../../templates/ssh/client/cloud-ca-ready.nix;
      unreliable = import ../../templates/ssh/client/unreliable.nix;
      corporate = import ../../templates/ssh/client/corporate.nix;
      legacy = import ../../templates/ssh/client/legacy.nix;
    };
  };

  gitHostPins = import ../../templates/ssh/known-hosts/git-hosts.nix;
  hostCaSkeleton = import ../../templates/ssh/known-hosts/host-ca-skeleton.nix;

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
    "cloud-ca-ready" = t.client.cloudCaReady;
    unreliable = t.client.unreliable;
    corporate = t.client.corporate;
    legacy = t.client.legacy;
  };

  profilePresets = {
    hardened = {
      clientProfile = "hardened";
      clientFeatures = [ ];
    };
    developer = {
      clientProfile = "developer";
      clientFeatures = [ ];
    };
    custom = {
      clientProfile = cfg.client.profile;
      clientFeatures = cfg.client.features;
    };
  };

  selectedProfile = lib.getAttr cfg.profile profilePresets;
  effectiveProfile = selectedProfile.clientProfile;
  effectiveFeatures = selectedProfile.clientFeatures;
  profileLocked = cfg.profile != "custom";

  profileTemplate = profile: (lib.getAttr profile clientProfiles) { inherit lib; };

  featureTemplates =
    features: map (feature: (lib.getAttr feature clientFeatures) { inherit lib; }) features;

  mapPins =
    pins:
    lib.mapAttrs (host: publicKey: {
      hostNames = [ host ];
      inherit publicKey;
    }) pins;

  mapHostKeys =
    hostKeys:
    lib.mapAttrs (host: cfg': {
      hostNames = if cfg'.hostNames != [ ] then cfg'.hostNames else [ host ];
      publicKey = cfg'.publicKey;
    }) hostKeys;

  providerPatternSuffixes = [
    "amazonaws.com"
    "amazonaws.com.cn"
    "azure.com"
    "visualstudio.com"
    "dev.azure.com"
  ];

  isProviderPattern = pattern: lib.any (suffix: lib.hasSuffix suffix pattern) providerPatternSuffixes;

  caActive = cfg.knownHosts.enable && cfg.knownHosts.ca.enable;

  caBundleProviderViolations = lib.flatten (
    lib.mapAttrsToList (
      name: bundle: map (pattern: "${name}:${pattern}") (lib.filter isProviderPattern bundle.patterns)
    ) cfg.knownHosts.ca.bundles
  );

  caKnownHosts = hostCaSkeleton {
    inherit lib;
    ca = cfg.knownHosts.ca;
  };

  enabledKnownHostBundles = lib.flatten [
    (lib.optional (lib.elem "git-hosts" effectiveFeatures) gitHostPins)
    (lib.optional (cfg.knownHosts.pins != { }) (mapPins cfg.knownHosts.pins))
    (lib.optional (cfg.hostKeys != { }) (mapHostKeys cfg.hostKeys))
    (lib.optional caActive caKnownHosts)
    (lib.optional (lib.elem "cloud" effectiveFeatures && cfg.cloud.caPublicKey != null) {
      awsCA = {
        hostNames = [ "@cert-authority *.compute.amazonaws.com" ];
        publicKey = cfg.cloud.caPublicKey;
      };
    })
  ];

  mergedKnownHosts = lib.mkMerge enabledKnownHostBundles;

  clientModule =
    { lib, ... }:
    {
      config = lib.mkMerge (
        [
          (t.client.base { inherit lib; })
          (profileTemplate effectiveProfile)
          (lib.mkIf cfg.client.onePasswordAgent.enable {
            programs.ssh.extraConfig = lib.mkAfter ''
              IdentityAgent ~/.1password/agent.sock
            '';
          })
        ]
        ++ featureTemplates effectiveFeatures
      );
    };

  insecureFeatures = [
    "legacy"
    "unreliable"
  ];
  insecureUsed = lib.filter (feature: lib.elem feature effectiveFeatures) insecureFeatures;
in
{
  options.my.ssh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable declarative SSH client/server configuration.";
    };

    profile = lib.mkOption {
      type = lib.types.enum [
        "hardened"
        "developer"
        "custom"
      ];
      default = "custom";
      description = ''
        High-level SSH preset selector.
        Use "custom" to manage my.ssh.client.* directly.
      '';
    };

    allowInsecure = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow legacy or insecure SSH feature bundles.";
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
        description = "SSH client profile to apply (custom profile mode).";
      };

      features = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "git-hosts"
            "bastion"
            "cloud"
            "cloud-ca-ready"
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

      ca = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable SSH host CA trust bundles (explicit opt-in).";
        };

        bundles = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                patterns = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Domain patterns for @cert-authority entries.";
                };
                publicKey = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "SSH host CA public key (verified out-of-band).";
                };
                comment = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Optional comment for the CA bundle.";
                };
              };
            }
          );
          default = { };
          description = "Host CA bundles keyed by name.";
        };

        allowProviderPatterns = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow provider domain patterns (unsafe unless you control issuance).";
        };
      };
    };

    hostKeys = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            publicKey = lib.mkOption {
              type = lib.types.str;
              description = "SSH host public key (verified out-of-band).";
            };
            hostNames = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Optional additional hostnames (defaults to attr name).";
            };
          };
        }
      );
      default = { };
      description = ''
        Manually pinned SSH host keys.

        Intended for providers without a stable global host key
        (e.g. Azure DevOps, AWS CodeCommit, SourceHut, self-hosted Git).
      '';
    };

    cloud.caPublicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional SSH CA public key for cloud host certificates.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf profileLocked {
        my.ssh.client.profile = lib.mkDefault effectiveProfile;
        my.ssh.client.features = lib.mkDefault effectiveFeatures;
      })
      (lib.mkIf cfg.client.enable {
        # HM owns client UX (matchBlocks, extraConfig, multiplexing).
        home-manager.sharedModules = [ clientModule ];
      })
      # NixOS owns trust roots (known_hosts pins / CA).
      (lib.mkIf cfg.knownHosts.enable {
        programs.ssh.knownHosts = mergedKnownHosts;
      })
      {
        assertions =
          lib.optionals caActive [
            {
              assertion = cfg.knownHosts.ca.bundles != { };
              message = "my.ssh.knownHosts.ca.enable is true, but no CA bundles are defined.";
            }
            {
              assertion = lib.all (bundle: bundle.patterns != [ ]) (lib.attrValues cfg.knownHosts.ca.bundles);
              message = "Each my.ssh.knownHosts.ca.bundles entry must define non-empty patterns.";
            }
            {
              assertion = lib.all (bundle: bundle.publicKey != "") (lib.attrValues cfg.knownHosts.ca.bundles);
              message = "Each my.ssh.knownHosts.ca.bundles entry must define a non-empty publicKey.";
            }
            {
              assertion = cfg.knownHosts.ca.allowProviderPatterns || caBundleProviderViolations == [ ];
              message = ''
                SSH host CA patterns include provider domains (${lib.concatStringsSep ", " caBundleProviderViolations}).
                Use domains you control or set my.ssh.knownHosts.ca.allowProviderPatterns = true.
              '';
            }
          ]
          ++ [
            {
              assertion =
                (!profileLocked)
                || (cfg.client.profile == effectiveProfile && cfg.client.features == effectiveFeatures);
              message = ''
                my.ssh.profile is set to "${cfg.profile}".
                Override my.ssh.client.* only when my.ssh.profile = "custom".
              '';
            }
            {
              assertion = cfg.allowInsecure || insecureUsed == [ ];
              message = ''
                my.ssh.client.features includes insecure bundles (${lib.concatStringsSep ", " insecureUsed}).
                Set my.ssh.allowInsecure = true to acknowledge the risk.
              '';
            }
          ];

        warnings =
          lib.optionals (insecureUsed != [ ] && cfg.allowInsecure) [
            "my.ssh.client.features contains insecure bundles (${lib.concatStringsSep ", " insecureUsed}); use only as a last resort."
          ]
          ++
            lib.optional (cfg.knownHosts.enable && builtins.length (builtins.attrNames mergedKnownHosts) == 0)
              ''
                SSH knownHosts enabled, but no host pins or CA bundles are configured.
                This is safe, but provides no trust roots.
                Consider enabling a bundle (e.g. "git-hosts") or adding explicit pins.
              '';
      }
    ]
  );
}
