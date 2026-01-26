{ config, lib, pkgs, ... }:

let
  cfg = config.my.security.luks.gpg;
  hasTrezorOne =
    config.my.install.hardwareAuth.trezor.present
    && config.my.install.hardwareAuth.trezor.model == "one";
  cryptsetupUnit = "systemd-cryptsetup@${lib.escapeSystemdPath cfg.mapperName}.service";

  decryptScript = pkgs.writeShellScript "nyxos-luks-gpg-decrypt" ''
    set -euo pipefail
    umask 077

    key_mount="${cfg.encryptedKeyMount}"
    key_device="${cfg.encryptedKeyDevice}"
    key_fstype="${cfg.encryptedKeyFsType}"
    key_opts="${cfg.encryptedKeyMountOptions}"
    enc_key="${cfg.encryptedKeyFile}"
    dec_key="${cfg.decryptedKeyFile}"
    gnupg_home="${cfg.gnupgHome}"
    pinentry="${cfg.pinentryPackage}/bin/pinentry-curses"

    mkdir -p "$gnupg_home"
    chmod 700 "$gnupg_home"

    cat > "$gnupg_home/gpg-agent.conf" <<EOF_CONF
pinentry-program $pinentry
EOF_CONF

    export GNUPGHOME="$gnupg_home"
    export GPG_TTY=/dev/console

    mkdir -p "$(dirname "$dec_key")"

    if [[ -n "$key_device" ]]; then
      mkdir -p "$key_mount"
      mount -t "$key_fstype" -o "$key_opts" "$key_device" "$key_mount"
    fi

    if [[ ! -f "$enc_key" ]]; then
      echo "Encrypted keyfile not found: $enc_key" >&2
      exit 1
    fi

    gpgconf --launch gpg-agent
    gpg --batch --yes --decrypt --output "$dec_key" "$enc_key"
    chmod 600 "$dec_key"

    if [[ -n "$key_device" ]]; then
      umount "$key_mount"
    fi
  '';

  wipeScript = pkgs.writeShellScript "nyxos-luks-gpg-wipe" ''
    set -euo pipefail
    key="${cfg.decryptedKeyFile}"
    if [[ -f "$key" ]]; then
      if command -v shred >/dev/null 2>&1; then
        shred -u "$key"
      else
        chmod 000 "$key" || true
        rm -f "$key"
      fi
    fi
  '';

  gateEnabled = cfg.enable && hasTrezorOne;
in
{
  options.my.security.luks.gpg = {
    enable = lib.mkEnableOption "GPG-decrypted LUKS keyfile unlock" // {
      default = config.my.install.luksGpg.enable or false;
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = config.my.install.luksGpg.device or "";
      description = "Block device for the LUKS volume to unlock.";
    };

    mapperName = lib.mkOption {
      type = lib.types.str;
      default = config.my.install.luksGpg.mapperName or "root";
      description = "Mapper name for the unlocked LUKS device.";
    };

    encryptedKeyFile = lib.mkOption {
      type = lib.types.str;
      default = config.my.install.luksGpg.encryptedKeyFile or "/persist/keys/root.key.gpg";
      description = "Encrypted keyfile path on the persistent mount (do not store in the repo or Nix store).";
    };

    encryptedKeyDevice = lib.mkOption {
      type = lib.types.str;
      default = config.my.install.luksGpg.encryptedKeyDevice or "/dev/disk/by-label/persist";
      description = "Device that holds the encrypted keyfile (mounted in initrd).";
    };

    encryptedKeyFsType = lib.mkOption {
      type = lib.types.str;
      default = config.my.install.luksGpg.encryptedKeyFsType or "btrfs";
      description = "Filesystem type for the encrypted keyfile device.";
    };

    encryptedKeyMount = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Mount point for the encrypted keyfile device inside initrd.";
    };

    encryptedKeyMountOptions = lib.mkOption {
      type = lib.types.str;
      default = "ro";
      description = "Mount options for the encrypted keyfile device in initrd.";
    };

    decryptedKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/nyxos/keys/root.key";
      description = "Tmpfs path for the decrypted keyfile inside initrd.";
    };

    gnupgHome = lib.mkOption {
      type = lib.types.str;
      default = "/run/nyxos/gnupg";
      description = "Temporary GNUPG home for initrd smartcard access.";
    };

    pinentryPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pinentry-curses;
      description = "Pinentry package for initrd GPG prompts.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf gateEnabled {
      boot.initrd.systemd.packages =
        [
          pkgs.coreutils
          pkgs.gnupg
          pkgs.util-linux
          cfg.pinentryPackage
        ]
        ++ lib.optional (cfg.encryptedKeyFsType == "btrfs") pkgs.btrfs-progs;

      boot.initrd.luks.devices.${cfg.mapperName} = {
        device = cfg.device;
        keyFile = cfg.decryptedKeyFile;
        allowDiscards = config.my.install.storage.trim.allowDiscardsInLuks;
      };

      boot.initrd.systemd.services.nyxos-luks-gpg = {
        description = "Decrypt LUKS keyfile with GPG";
        wantedBy = [ "cryptsetup.target" ];
        before = [ "cryptsetup.target" cryptsetupUnit ];
        after = [ "systemd-udevd.service" "systemd-udev-settle.service" ];
        unitConfig = {
          DefaultDependencies = "no";
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = decryptScript;
        };
      };

      boot.initrd.systemd.services.nyxos-luks-gpg-cleanup = {
        description = "Wipe decrypted LUKS keyfile from tmpfs";
        wantedBy = [ "initrd.target" ];
        after = [ cryptsetupUnit ];
        before = [ "initrd-switch-root.target" ];
        unitConfig = {
          DefaultDependencies = "no";
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = wipeScript;
        };
      };

      assertions = [
        {
          assertion = config.my.install.encryption.mode == "luks2";
          message = "luks-gpg: my.install.encryption.mode must be set to luks2 when enabling initrd GPG unlock.";
        }
        {
          assertion = cfg.device != "";
          message = "luks-gpg: device must be set when initrd GPG unlock is enabled.";
        }
        {
          assertion = cfg.mapperName != "";
          message = "luks-gpg: mapperName must be set when initrd GPG unlock is enabled.";
        }
        {
          assertion = cfg.encryptedKeyDevice != "";
          message = "luks-gpg: encryptedKeyDevice must be set when initrd GPG unlock is enabled.";
        }
        {
          assertion = lib.hasPrefix cfg.encryptedKeyMount cfg.encryptedKeyFile;
          message = "luks-gpg: encryptedKeyFile must live under encryptedKeyMount.";
        }
        {
          assertion = lib.hasPrefix "/run/" cfg.decryptedKeyFile;
          message = "luks-gpg: decryptedKeyFile must live under /run (tmpfs).";
        }
        {
          assertion = !(lib.hasPrefix "/nix/store" cfg.encryptedKeyFile);
          message = "luks-gpg: encryptedKeyFile must not live in /nix/store.";
        }
      ];
    })
    {
      assertions = [
        {
          assertion = !(cfg.enable && !hasTrezorOne);
          message = "luks-gpg: enable requires my.install.hardwareAuth.trezor.present = true and model = one.";
        }
      ];
    }
  ];
}
