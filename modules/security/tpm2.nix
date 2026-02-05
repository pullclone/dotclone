{ config, lib, ... }:

let
  cfg = config.my.install.encryption.tpm2;
in
{
  config = lib.mkIf cfg.enable {
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
    };

    # TPM2 LUKS tokens require systemd in initrd and LUKS2 metadata.
    boot.initrd.systemd.enable = true;
    boot.initrd.luks.forceLuks2 = true;

    assertions = [
      {
        assertion = config.my.install.encryption.mode == "luks2";
        message = "tpm2: encryption.mode must be luks2 when TPM2 unlock is enabled.";
      }
    ];
  };
}
