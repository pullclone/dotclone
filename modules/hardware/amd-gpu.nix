{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ==========================================
  # AMD KERNEL PARAMETERS
  # ==========================================
  boot.kernelParams = [
    "amd_pstate=active"
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # ==========================================
  # GRAPHICS STACK
  # ==========================================
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocm-runtime
    ];
  };

  # Fix for ROCm HIP libraries
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  # ==========================================
  # HARDWARE PACKAGES
  # ==========================================
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    nvtopPackages.amd
  ];
}
