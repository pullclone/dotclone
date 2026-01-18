{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.install.nvidia;
  isHybrid = cfg.mode != "desktop";
  hasNvidia = config.my.install.hardware.gpu.hasNvidia;
in
{
  config = lib.mkIf (hasNvidia && cfg.enable) {
    # NVIDIA requires unfree; scope it here for clarity.
    nixpkgs.config.allowUnfree = true;

    hardware.graphics = {
      enable = true;
      enable32Bit = true; # steam/proton and some Vulkan stacks need 32-bit GL/VK
    };

    services.xserver.videoDrivers =
      if isHybrid then
        [
          "modesetting"
          "nvidia"
        ]
      else
        [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      open = cfg.open;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement.enable = lib.mkDefault false;

      prime = lib.mkIf isHybrid {
        offload = lib.mkIf (cfg.mode == "laptop-offload") {
          enable = true;
          enableOffloadCmd = true;
        };
        sync = lib.mkIf (cfg.mode == "laptop-sync") {
          enable = true;
        };
        # Assign bus IDs; only one of intel/amdgpu should be set.
        inherit (cfg) nvidiaBusId intelBusId amdgpuBusId;
      };
    };

    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia
    ];

    assertions = [
      {
        assertion =
          (!isHybrid) || (cfg.nvidiaBusId != "" && ((cfg.intelBusId != "") != (cfg.amdgpuBusId != "")));
        message = "nvidia: hybrid modes require nvidiaBusId and exactly one of intelBusId or amdgpuBusId.";
      }
    ];
  };
}
