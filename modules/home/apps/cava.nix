{ config, pkgs, ... }:

{
  programs.cava = {
    enable = true;
    settings = {
      general = {
        framerate = 60;
        autosens = 1;
        overshoot = 20;
        sensitivity = 100;
        bars = 0;
        bar_width = 3;
        bar_spacing = 2;
      };

      input = {
        method = "pulse";
        source = "auto";
      };

      output = {
        method = "ncurses";
        channels = "stereo";
      };

      color = {
        gradient = 1;
        gradient_count = 8;
        # Your specific Aurora colors
        gradient_color_1 = "'#94e2d5'";
        gradient_color_2 = "'#89dceb'";
        gradient_color_3 = "'#74c7ec'";
        gradient_color_4 = "'#89b4fa'";
        gradient_color_5 = "'#cba6f7'";
        gradient_color_6 = "'#f5c2e7'";
        gradient_color_7 = "'#eba0ac'";
        gradient_color_8 = "'#f38ba8'";
      };

      smoothing = {
        integral = 70;
        monstercat = 1;
        waves = 0;
        gravity = 100;
      };
    };
  };
}
