{ config, pkgs, ... }:

{
  # Tell Stylix to ignore btop so our custom settings stick
  stylix.targets.btop.enable = false;

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "catppuccin_mocha";
      theme_background = false;
      truecolor = true;
      vim_keys = true;
      update_ms = 500;
    };
  };
}
