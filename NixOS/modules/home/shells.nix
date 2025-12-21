{ config, pkgs, ... }:

let
  aliases = {
    # Navigation
    ".." = "cd ..";
    "..." = "cd ../..";
    "~" = "cd ~";

    # System & Utils
    "c" = "clear";
    "zero" = "clear";
    "path" = "echo $PATH";
    "ls" = "eza -a -1 --icons --group-directories-first";
    "ll" = "eza -l --icons --group-directories-first --time-style=\"%Y-%m-%d %H:%M\"";
    "zeit" = "date +\"%T\"";
    "era" = "date +\"%d-%m-%Y\"";
    "log" = "history";
    "booba" = "history -c";

    # File Operations
    "rm" = "trash-put";
    "del" = "trash-put";
    "empty" = "trash-empty";
    "cp" = "cp -i";
    "mv" = "mv -i";

    # Editors & Tools
    "edit" = "micro";

    # AI Chat Swapper
    "aiswap" = "aichat-swap";
    "altostrat" = "aichat-swap c";
    "alpha" = "aichat-swap g";
    "lechat" = "aichat-swap m";
    "stargate" = "aichat-swap o";

    # Quick AI Models (Sed replacement)
    "align" = "sed -i \"s/^model:.*/model: openai:gpt-4o/\" ~/.config/aichat/config.yaml && aichat";
    "bunz" = "sed -i \"s/^model:.*/model: openai:gpt-5-chat-latest/\" ~/.config/aichat/config.yaml && aichat";
    "core" = "sed -i \"s/^model:.*/model: openai:gpt-5-mini/\" ~/.config/aichat/config.yaml && aichat";
    "mai" = "sed -i \"s/^model:.*/model: openai:o4-mini/\" ~/.config/aichat/config.yaml && aichat";

    # Config Shortcuts
    "srcfile" = "micro $HOME/.bashrc";
    "nixconf" = "micro /etc/nixos/configuration.nix";
    "hyprfile" = "micro $HOME/.config/niri/config.kdl";

    # Clipboard (Launcher Agnostic)
    "clipboard" = "cliphist list | $LAUNCHER_CMD | cliphist decode | wl-copy";
    "cb" = "cliphist list | $LAUNCHER_CMD | cliphist decode | wl-copy";
  };
in
{
  # --- BAT (Better Cat) ---
  # We disable Stylix for Bat so we can enforce our specific Catppuccin theme
  stylix.targets.bat.enable = false;

  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Mocha";
      style = "header,grid";
    };
    themes = {
      "Catppuccin Mocha" = {
        src = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "bat";
          rev = "ba4d16880d63e656acced2b7d4e034e4a93f74b1";
          sha256 = "sha256-6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
        };
        file = "themes/Catppuccin Mocha.tmTheme";
      };
    };
  };

  # --- GLOBAL ENVIRONMENT ---
  home.sessionVariables = {
    EDITOR = "micro";
    VISUAL = "micro";
    PAGER = "less";
    QS_ICON_THEME = "Papirus-Dark";
    HISTSIZE = "1000000";
    HISTFILESIZE = "2000000";
    HISTTIMEFORMAT = "%F %T ";
    HISTCONTROL = "erasedups:ignoredups:ignorespace";
    NIXOS_OZONE_WL = "1";
    GOPATH = "${config.home.homeDirectory}/go";
    GOBIN = "${config.home.homeDirectory}/go/bin";
  };

  # --- BASH ---
  programs.bash = {
    enable = true;
    shellAliases = aliases;
    initExtra = ''
      shopt -s checkwinsize
      shopt -s histappend
      bind "set completion-ignore-case on" 2>/dev/null
      bind "set show-all-if-ambiguous on" 2>/dev/null

      PROMPT_COMMAND="history -a"

      extract() {
        for file in "$@"; do
          if [[ -f "$file" ]]; then
            case "$file" in
              *.tar.bz2) tar xjf "$file" ;;
              *.tar.gz)  tar xzf "$file" ;;
              *.tar.xz)  tar xJf "$file" ;;
              *.bz2)     bunzip2 "$file" ;;
              *.rar)     unrar x "$file" ;;
              *.gz)      gunzip "$file" ;;
              *.tar)     tar xf "$file" ;;
              *.tbz2)    tar xjf "$file" ;;
              *.tgz)     tar xzf "$file" ;;
              *.zip)     unzip "$file" ;;
              *.Z)       uncompress "$file" ;;
              *.7z)      7z x "$file" ;;
              *)         echo "Unknown archive format: $file" ;;
            esac
          else
            echo "File not found: $file"
          fi
        done
      }

      if command -v macchina >/dev/null 2>&1; then
          macchina -c "$HOME/.config/macchina/macchina.toml"
      fi
    '';
  };

  # --- FISH ---
  programs.fish = {
    enable = true;
    shellAliases = aliases;
    functions = {
      extract = {
        body = ''
          for file in $argv
            if test -f $file
              switch $file
                case '*.tar.bz2'; tar xjf $file
                case '*.tar.gz';  tar xzf $file
                case '*.tar.xz';  tar xJf $file
                case '*.bz2';     bunzip2 $file
                case '*.rar';     unrar x $file
                case '*.gz';      gunzip $file
                case '*.tar';     tar xf $file
                case '*.tbz2';    tar xjf $file
                case '*.tgz';     tar xzf $file
                case '*.zip';     unzip $file
                case '*.Z';       uncompress $file
                case '*.7z';      7z x $file
                case '*';         echo "Unknown extension: $file"
              end
            else
              echo "File not found: $file"
            end
          end
        '';
      };

      mkcd = { body = "mkdir -p $argv[1]; and cd $argv[1]"; };
      up = { body = "cd (string repeat -n $argv[1] '../')"; };
    };

    interactiveShellInit = ''
      set -g fish_greeting ""

      # TTY Colors (Applied only in Linux Console)
      if test "$TERM" = "linux"
          printf %b '\e]P01E1E2E' # Base
          printf %b '\e]P8585B70' # Surface2
          printf %b '\e]P7BAC2DE' # Text
          printf %b '\e]PFA6ADC8' # Subtext0
          printf %b '\e]P1F38BA8' # Red
          printf %b '\e]P9F38BA8' # Bright Red
          printf %b '\e]P2A6E3A1' # Green
          printf %b '\e]PAA6E3A1' # Bright Green
          printf %b '\e]P3F9E2AF' # Yellow
          printf %b '\e]PBF9E2AF' # Bright Yellow
          printf %b '\e]P489B4FA' # Blue
          printf %b '\e]PC89B4FA' # Bright Blue
          printf %b '\e]P5F5C2E7' # Pink
          printf %b '\e]PDF5C2E7' # Bright Pink
          printf %b '\e]P694E2D5' # Teal
          printf %b '\e]PE94E2D5' # Bright Teal
          clear
      end

      if type -q macchina; macchina -c "$HOME/.config/macchina/macchina.toml"; end
    '';
  };

  # --- STARSHIP (Aurora Style) ---
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    settings = {
      format = "$directory$git_branch$character";

      character = {
        success_symbol = "[🞈](#a6e3a1 bold)";
        error_symbol = "[🞈](#f38ba8)";
        vicmd_symbol = "[🞈](#f9e2af)";
      };

      directory = {
        format = "[]($style)[$path](bg:#89b4fa fg:#222436)[ ]($style)";
        style = "bg:none fg:#89b4fa";
        truncation_length = 3;
        truncate_to_repo = false;
      };

      git_branch = {
        format = "[]($style)[[ ](bg:#89b4fa fg:#222436 bold)$branch](bg:#89b4fa fg:#222436)[ ]($style)";
        style = "bg:none fg:#89b4fa";
      };
    };
  };

  # --- ZOXIDE ---
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };
}
