{ config, pkgs, ... }:

{
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
