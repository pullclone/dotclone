{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    themeFile = "${pkgs.kitty-themes}/share/kitty-themes/themes/Catppuccin-Mocha.conf";
    font = {
      name = "FiraCode Nerd Font";
      size = 11.0;
    };
    settings = {
      window_padding_width = 15;
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      symbol_map = "U+E0A0-U+E0A3,U+E0C0-U+E0C7 PowerlineSymbols";
      confirm_os_window_close = 0;
    };
  };
}
