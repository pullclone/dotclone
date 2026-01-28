{ lib, config, ... }:

let
  answersPath = "/etc/nixos/nyxos-install.nix";
  answers = if builtins.pathExists answersPath then import answersPath else { };

  hostName = answers.hostName or "nyx";
  timeZone = answers.timeZone or "UTC";
  userName = answers.userName or "ashy";
  keyboardPresets = [
    "qwerty"
    "dvorak"
    "colemak"
    "workman"
    "halmak"
    "engram-v2"
    "bepo"
    "neo"
    "eurkey"
    "eurkey-colemak-dh"
  ];
  keyboard =
    answers.keyboard or {
      enable = true;
      preset = "qwerty";
    };
  mac = answers.mac or { mode = "default"; };
  boot = answers.boot or { mode = "uki"; };
  trust = answers.trust or { phase = "dev"; };
  hardwareAuth =
    let
      hw = answers.hardwareAuth or { };
      trezor = hw.trezor or { };
      fido2 = hw.fido2 or { };
    in
    {
      trezor = {
        present = trezor.present or false;
        model = trezor.model or "unknown";
      };
      fido2 = {
        present = fido2.present or false;
      };
    };
  ssh =
    let
      sshAnswers = answers.ssh or { };
    in
    {
      identity = sshAnswers.identity or "file";
    };
  sshPolicy =
    if
      (answers ? my)
      && builtins.isAttrs answers.my
      && (answers.my ? ssh)
      && builtins.isAttrs answers.my.ssh
    then
      answers.my.ssh
    else
      { };
  snapshots =
    answers.snapshots or {
      retention = -1;
      schedule = "daily";
      prePostRebuild = true;
      remote = {
        enable = false;
        target = "";
      };
    };
  storage =
    answers.storage or {
      trim = {
        enable = true;
        interval = "weekly";
        allowDiscardsInLuks = true;
      };
    };
  encryption = answers.encryption or { mode = "none"; };
  luksGpg =
    answers.luksGpg or {
      enable = false;
      device = "";
      mapperName = "root";
      encryptedKeyFile = "/persist/keys/root.key.gpg";
      encryptedKeyDevice = "/dev/disk/by-label/persist";
      encryptedKeyFsType = "ext4";
    };
  swap =
    answers.swap or {
      mode = "partition";
      sizeGiB = 8;
    };
  protonvpn =
    answers.protonvpn or {
      enable = false;
    };
  gaming =
    answers.gaming or {
      steam = false;
      gamemode = false;
      gamescope = false;
      lutris = false;
      lutrisRsi = false;
      wine = false;
      emulationstation = false;
    };
  profile = answers.profile or { system = "balanced"; };
  hardware =
    let
      hw = answers.hardware or { };
      gpu = hw.gpu or { };
    in
    {
      cpuVendor = hw.cpuVendor or "unknown";
      gpu = {
        hasNvidia = gpu.hasNvidia or false;
        hasAmd = gpu.hasAmd or false;
        hasIntel = gpu.hasIntel or false;
        primary = gpu.primary or "unknown";
      };
    };
  nvidia =
    answers.nvidia or {
      enable = false;
      mode = "desktop";
      open = true;
      intelBusId = "";
      amdgpuBusId = "";
      nvidiaBusId = "";
    };
in
{
  options.my.install = {
    userName = lib.mkOption {
      type = lib.types.str;
      default = userName;
      description = "Primary username set during installation.";
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      default = hostName;
      description = "System host name.";
    };
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = timeZone;
      description = "Default time zone.";
    };
    keyboard = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = keyboard.enable;
            description = "Whether the keyboard preset should be applied.";
          };
          preset = lib.mkOption {
            type = lib.types.enum keyboardPresets;
            default = keyboard.preset;
            description = "Keyboard layout preset selected at install time.";
          };
        };
      };
      default = keyboard;
      description = "Keyboard layout facts from install answers.";
    };
    mac = lib.mkOption {
      type = lib.types.attrs;
      default = mac;
      description = "MAC address randomisation policy.";
    };
    boot.mode = lib.mkOption {
      type = lib.types.enum [
        "uki"
        "secureboot"
      ];
      default = boot.mode;
      description = ''
        Boot profile to use: “uki” for a plain UKI baseline, or “secureboot” for Lanzaboote Secure Boot.
        Exactly one profile must be enabled.
      '';
    };
    trust.phase = lib.mkOption {
      type = lib.types.enum [
        "dev"
        "enforced"
      ];
      default = trust.phase;
      description = ''
        Trust phase: “dev” defers TPM/Secure‑Boot assertions; “enforced” requires firmware SB and TPM sealing.
      '';
    };
    hardwareAuth = lib.mkOption {
      type = lib.types.submodule {
        options = {
          trezor = lib.mkOption {
            type = lib.types.submodule {
              options = {
                present = lib.mkOption {
                  type = lib.types.bool;
                  default = hardwareAuth.trezor.present;
                  description = "Whether a Trezor device is available for hardware auth.";
                };
                model = lib.mkOption {
                  type = lib.types.enum [
                    "one"
                    "t"
                    "unknown"
                  ];
                  default = hardwareAuth.trezor.model;
                  description = "Trezor hardware model.";
                };
              };
            };
            default = hardwareAuth.trezor;
            description = "Trezor hardware facts.";
          };
          fido2 = lib.mkOption {
            type = lib.types.submodule {
              options = {
                present = lib.mkOption {
                  type = lib.types.bool;
                  default = hardwareAuth.fido2.present;
                  description = "Whether a FIDO2/CTAP2 device is available.";
                };
              };
            };
            default = hardwareAuth.fido2;
            description = "FIDO2 hardware facts.";
          };
        };
      };
      default = hardwareAuth;
      description = "Hardware authentication device facts from install answers.";
    };
    ssh = lib.mkOption {
      type = lib.types.submodule {
        options = {
          identity = lib.mkOption {
            type = lib.types.enum [
              "file"
              "fido2"
            ];
            default = ssh.identity;
            description = "SSH identity mode (file-based or FIDO2-backed).";
          };
        };
      };
      default = ssh;
      description = "SSH identity preference captured at install time.";
    };
    snapshots.retention = lib.mkOption {
      type = lib.types.int;
      default = snapshots.retention;
      description = ''
        Number of snapshots to retain for btrbk.
        -1 → do not configure snapshots; 0 → disable snapshots; >0 → enable snapshots with this retention.
      '';
    };
    snapshots.schedule = lib.mkOption {
      type = lib.types.str;
      default = snapshots.schedule;
      description = "Snapshot schedule (e.g. “daily”).  Used by btrbk.";
    };
    snapshots.prePostRebuild = lib.mkOption {
      type = lib.types.bool;
      default = snapshots.prePostRebuild;
      description = "Whether to take snapshots before and after nixos-rebuild.";
    };
    snapshots.remote = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = snapshots.remote.enable or false;
            description = "Enable remote snapshot replication.";
          };
          target = lib.mkOption {
            type = lib.types.str;
            default = snapshots.remote.target or "";
            description = "Remote target (e.g., user@host:/path).";
          };
        };
      };
      default = snapshots.remote;
      description = "Remote snapshot replication settings.";
    };
    storage.trim.enable = lib.mkOption {
      type = lib.types.bool;
      default = storage.trim.enable;
      description = "Enable periodic fstrim.";
    };
    storage.trim.interval = lib.mkOption {
      type = lib.types.str;
      default = storage.trim.interval;
      description = "TRIM interval (e.g. “weekly”).";
    };
    storage.trim.allowDiscardsInLuks = lib.mkOption {
      type = lib.types.bool;
      default = storage.trim.allowDiscardsInLuks;
      description = "Allow discards through LUKS (future encrypted installs).";
    };
    encryption.mode = lib.mkOption {
      type = lib.types.enum [
        "none"
        "luks2"
      ];
      default = encryption.mode;
      description = ''
        Encryption intent: “none” for unencrypted root, “luks2” to signal LUKS2 should be used by an encrypted installer.
      '';
    };
    luksGpg = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = luksGpg.enable;
            description = "Enable GPG-decrypted LUKS keyfile unlock in initrd.";
          };
          device = lib.mkOption {
            type = lib.types.str;
            default = luksGpg.device;
            description = "LUKS device path to unlock (e.g., /dev/disk/by-uuid/...).";
          };
          mapperName = lib.mkOption {
            type = lib.types.str;
            default = luksGpg.mapperName;
            description = "Mapper name for the unlocked device.";
          };
          encryptedKeyFile = lib.mkOption {
            type = lib.types.str;
            default = luksGpg.encryptedKeyFile;
            description = "Path to the encrypted keyfile on the persistent mount.";
          };
          encryptedKeyDevice = lib.mkOption {
            type = lib.types.str;
            default = luksGpg.encryptedKeyDevice;
            description = "Device containing the encrypted keyfile (mounted in initrd).";
          };
          encryptedKeyFsType = lib.mkOption {
            type = lib.types.str;
            default = luksGpg.encryptedKeyFsType;
            description = "Filesystem type for the encrypted keyfile device.";
          };
        };
      };
      default = luksGpg;
      description = "GPG-decrypted LUKS keyfile facts captured at install time.";
    };
    swap.mode = lib.mkOption {
      type = lib.types.enum [
        "partition"
        "none"
      ];
      default = swap.mode;
      description = "Swap provisioning strategy.";
    };
    swap.sizeGiB = lib.mkOption {
      type = lib.types.ints.nonNegative;
      default = swap.sizeGiB;
      description = "Swap size in GiB (used when swap.mode = “partition”).";
    };
    protonvpn.enable = lib.mkOption {
      type = lib.types.bool;
      default = protonvpn.enable;
      description = "Enable ProtonVPN GUI for the primary user (Home Manager).";
    };
    gaming = lib.mkOption {
      type = lib.types.submodule {
        options = {
          steam = lib.mkOption {
            type = lib.types.bool;
            default = gaming.steam;
            description = "Enable Steam and supporting system prerequisites.";
          };
          gamemode = lib.mkOption {
            type = lib.types.bool;
            default = gaming.gamemode;
            description = "Enable Feral GameMode.";
          };
          gamescope = lib.mkOption {
            type = lib.types.bool;
            default = gaming.gamescope;
            description = "Enable gamescope and supporting packages.";
          };
          lutris = lib.mkOption {
            type = lib.types.bool;
            default = gaming.lutris;
            description = "Enable Lutris.";
          };
          lutrisRsi = lib.mkOption {
            type = lib.types.bool;
            default = gaming.lutrisRsi;
            description = "Enable RSI launcher support (nix-citizen) via Lutris.";
          };
          wine = lib.mkOption {
            type = lib.types.bool;
            default = gaming.wine;
            description = "Enable Wine (wineWowPackages + winetricks).";
          };
          emulationstation = lib.mkOption {
            type = lib.types.bool;
            default = gaming.emulationstation;
            description = "Enable EmulationStation (classic).";
          };
        };
      };
      default = gaming;
      description = "Gaming-related install facts.";
    };
    profile.system = lib.mkOption {
      type = lib.types.enum [
        "balanced"
        "latency"
        "throughput"
        "battery"
        "memory-saver"
      ];
      default = profile.system;
      description = "System tuning profile.";
    };
    hardware = lib.mkOption {
      type = lib.types.submodule {
        options = {
          cpuVendor = lib.mkOption {
            type = lib.types.enum [
              "amd"
              "intel"
              "unknown"
            ];
            default = hardware.cpuVendor;
            description = "Detected CPU vendor.";
          };
          gpu = lib.mkOption {
            type = lib.types.submodule {
              options = {
                hasNvidia = lib.mkOption {
                  type = lib.types.bool;
                  default = hardware.gpu.hasNvidia;
                  description = "Whether an NVIDIA GPU is present.";
                };
                hasAmd = lib.mkOption {
                  type = lib.types.bool;
                  default = hardware.gpu.hasAmd;
                  description = "Whether an AMD GPU is present.";
                };
                hasIntel = lib.mkOption {
                  type = lib.types.bool;
                  default = hardware.gpu.hasIntel;
                  description = "Whether an Intel GPU is present.";
                };
                primary = lib.mkOption {
                  type = lib.types.enum [
                    "nvidia"
                    "amd"
                    "intel"
                    "unknown"
                  ];
                  default = hardware.gpu.primary;
                  description = "Primary GPU vendor (for UX defaults).";
                };
              };
            };
            default = hardware.gpu;
            description = "Detected GPU vendors.";
          };
        };
      };
      default = hardware;
      description = "Detected hardware facts used for vendor-gated modules.";
    };
    nvidia = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = nvidia.enable;
        description = "Enable NVIDIA support.";
      };
      mode = lib.mkOption {
        type = lib.types.enum [
          "desktop"
          "laptop-offload"
          "laptop-sync"
        ];
        default = nvidia.mode;
        description = "NVIDIA mode: desktop (single GPU) or laptop PRIME offload/sync.";
      };
      open = lib.mkOption {
        type = lib.types.bool;
        default = nvidia.open;
        description = "Use the open NVIDIA kernel module when supported.";
      };
      intelBusId = lib.mkOption {
        type = lib.types.str;
        default = nvidia.intelBusId;
        description = "Intel iGPU bus ID (PCI:x:y:z) for hybrid laptops.";
      };
      amdgpuBusId = lib.mkOption {
        type = lib.types.str;
        default = nvidia.amdgpuBusId;
        description = "AMD iGPU bus ID (PCI:x:y:z) for hybrid laptops.";
      };
      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        default = nvidia.nvidiaBusId;
        description = "NVIDIA dGPU bus ID (PCI:x:y:z). Required for hybrid modes.";
      };
    };
  };

  config = {
    # propagate values to actual NixOS configuration
    networking.hostName = hostName;
    time.timeZone = timeZone;

    networking.networkmanager =
      lib.mkIf
        (builtins.elem mac.mode [
          "random"
          "stable"
        ])
        {
          wifi.macAddress = mac.mode;
          ethernet.macAddress = mac.mode;
        };
    networking.interfaces = lib.mkIf (mac.mode == "fixed") {
      "${mac.interface}".macAddress = mac.address;
    };

    # store all answers under config.my.install for use in other modules
    my.install = {
      inherit
        userName
        hostName
        timeZone
        keyboard
        mac
        snapshots
        encryption
        luksGpg
        swap
        profile
        hardware
        nvidia
        hardwareAuth
        ssh
        gaming
        ;
      boot = {
        mode = boot.mode;
      };
      trust = {
        phase = trust.phase;
      };
      storage.trim = storage.trim;
      protonvpn = {
        enable = protonvpn.enable;
      };
    };

    my.ssh = lib.mkDefault sshPolicy;

    assertions = [
      {
        assertion = swap.sizeGiB >= 0;
        message = "install answers: swap.sizeGiB must be non-negative";
      }
      {
        assertion =
          (!nvidia.enable)
          || (nvidia.mode == "desktop")
          || (nvidia.nvidiaBusId != "" && ((nvidia.intelBusId != "") != (nvidia.amdgpuBusId != "")));
        message = "install answers: NVIDIA hybrid mode requires nvidiaBusId and exactly one of intelBusId or amdgpuBusId.";
      }
      {
        assertion = lib.elem hardware.cpuVendor [
          "amd"
          "intel"
          "unknown"
        ];
        message = "install answers: hardware.cpuVendor must be amd, intel, or unknown.";
      }
      {
        assertion = lib.elem hardware.gpu.primary [
          "amd"
          "intel"
          "nvidia"
          "unknown"
        ];
        message = "install answers: hardware.gpu.primary must be amd, intel, nvidia, or unknown.";
      }
      {
        assertion =
          builtins.isBool hardware.gpu.hasNvidia
          && builtins.isBool hardware.gpu.hasAmd
          && builtins.isBool hardware.gpu.hasIntel;
        message = "install answers: hardware.gpu.hasNvidia/hasAmd/hasIntel must be booleans.";
      }
      {
        assertion = !(gaming.lutrisRsi && !gaming.lutris);
        message = "install answers: gaming.lutrisRsi requires gaming.lutris = true.";
      }
    ];
  };
}
