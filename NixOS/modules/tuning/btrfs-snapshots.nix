{ config, lib, pkgs, modulesPath, ... }:

let
  snaps = config.my.install.snapshots or { };
  retention = snaps.retention or (-1);
  remote = snaps.remote or { enable = false; target = ""; };

  snapshotsEnabled = retention > 0;
  remoteEnabled = snapshotsEnabled && (remote.enable or false);
in
{
  imports = [ (modulesPath + "/services/backup/btrbk.nix") ];

  config = lib.mkMerge [
    # Inert when retention = -1
    (lib.mkIf (retention == -1) { })

    # Explicitly disabled when retention = 0
    (lib.mkIf (retention == 0) {
      services.btrbk.instances = lib.mkForce { };
    })

    # Active when retention > 0
    (lib.mkIf snapshotsEnabled {
      assertions = [
        {
          assertion = !(remoteEnabled && (remote.target or "") == "");
          message = "btrbk remote replication enabled but snapshots.remote.target is empty";
        }
      ];

      environment.systemPackages = [ pkgs.btrbk ];

      services.btrbk.instances.main = {
        onCalendar = "daily";
        settings =
          let
            base = {
              snapshot_preserve_min = "2d";
              snapshot_preserve = "${toString retention}d";
              snapshot_dir = "/.snapshots";
              volume."/".subvolume = [
                "@"
                "@home"
              ];
            };
            remoteCfg = lib.optionalAttrs remoteEnabled {
              "target ${remote.target}" = {
                target_preserve_min = "2d";
                target_preserve = "${toString retention}d";
                stream_compress = "lz4";
                stream_buffer = "auto";
              };
            };
          in
          base // remoteCfg;
      };

      # Post-rebuild snapshot (best-effort) on switch
      system.activationScripts.btrbk-post-rebuild = lib.mkIf snaps.prePostRebuild {
        deps = [ "users" ];
        text = ''
          if command -v btrbk >/dev/null 2>&1; then
            echo "btrbk: taking post-rebuild snapshot..."
            btrbk run
          fi
        '';
      };
    })
  ];
}
