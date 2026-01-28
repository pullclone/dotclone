{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.keyboard;

  presets = [
    "qwerty"
    "dvorak"
    "colemak"
    "workman"
    "halmak"
    "engram-v2"
    "bepo"
    "neo"
    "eurkey"
    "eurkey-colemak-dh"
  ];

  presetMap = {
    qwerty = {
      xkb = {
        layout = "us";
        variant = "";
        options = "";
      };
      console = "us";
      needsCustomXkb = false;
    };
    dvorak = {
      xkb = {
        layout = "us";
        variant = "dvorak";
        options = "";
      };
      console = "dvorak";
      needsCustomXkb = false;
    };
    colemak = {
      xkb = {
        layout = "us";
        variant = "colemak";
        options = "";
      };
      console = "colemak";
      needsCustomXkb = false;
    };
    workman = {
      xkb = {
        layout = "us";
        variant = "workman";
        options = "";
      };
      console = "workman";
      needsCustomXkb = false;
    };
    halmak = {
      xkb = {
        layout = "halmak";
        variant = "";
        options = "";
      };
      console = "halmak";
      needsCustomXkb = true;
    };
    "engram-v2" = {
      xkb = {
        layout = "engram";
        variant = "v2";
        options = "";
      };
      console = "engram_v2";
      needsCustomXkb = true;
    };
    bepo = {
      xkb = {
        layout = "fr";
        variant = "bepo";
        options = "";
      };
      console = "fr-bepo";
      needsCustomXkb = false;
    };
    neo = {
      xkb = {
        layout = "de";
        variant = "neo";
        options = "";
      };
      console = "neo";
      needsCustomXkb = false;
    };
    eurkey = {
      xkb = {
        layout = "eurkey";
        variant = "";
        options = "";
      };
      console = "eurkey";
      needsCustomXkb = true;
    };
    "eurkey-colemak-dh" = {
      xkb = {
        layout = "eurkey";
        variant = "colemak_dh";
        options = "";
      };
      console = "eurkey_colemak_dh";
      needsCustomXkb = true;
    };
  };

  sel = presetMap.${cfg.preset};
  xkbDir = ./xkb;

  customSymbols = {
    engram = "${xkbDir}/symbols/engram";
    halmak = "${xkbDir}/symbols/halmak";
    eurkey = "${xkbDir}/symbols/eurkey";
  };

  symbolPath = customSymbols.${sel.xkb.layout} or null;
  symbolExists = symbolPath != null && builtins.pathExists symbolPath;

  customLayouts = {
    engram = {
      description = "Engram (v2 variant)";
      languages = [ "eng" ];
      symbolsFile = ./xkb/symbols/engram;
      variants = {
        v2 = {
          description = "Engram v2";
        };
      };
    };
    halmak = {
      description = "Halmak";
      languages = [ "eng" ];
      symbolsFile = ./xkb/symbols/halmak;
    };
    eurkey = {
      description = "EurKEY (and variants)";
      languages = [
        "eng"
        "deu"
        "fra"
        "spa"
        "ita"
        "nld"
      ];
      symbolsFile = ./xkb/symbols/eurkey;
      variants = {
        colemak_dh = {
          description = "EurKEY (Colemak-DH)";
        };
      };
    };
  };

  consoleKeyMap = if sel.needsCustomXkb then "custom/${sel.console}" else sel.console;

  sessionVars = {
    XKB_DEFAULT_LAYOUT = sel.xkb.layout;
  }
  // lib.optionalAttrs (sel.xkb.variant != "") {
    XKB_DEFAULT_VARIANT = sel.xkb.variant;
  }
  // lib.optionalAttrs (sel.xkb.options != "") {
    XKB_DEFAULT_OPTIONS = sel.xkb.options;
  };
  layoutArg = lib.escapeShellArg sel.xkb.layout;
  variantArg = lib.optionalString (
    sel.xkb.variant != ""
  ) " -variant ${lib.escapeShellArg sel.xkb.variant}";
  optionsArg = lib.optionalString (
    sel.xkb.options != ""
  ) " -option ${lib.escapeShellArg sel.xkb.options}";
  setxkbmapCmd = "${pkgs.xorg.setxkbmap}/bin/setxkbmap -layout ${layoutArg}${variantArg}${optionsArg}";

  mkConsoleKeymapsPkg =
    pkgs.runCommand "custom-console-keymaps"
      {
        nativeBuildInputs = [
          pkgs.ckbcomp
          pkgs.gzip
        ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out/share/kbd/keymaps/custom"

        XKB_DIR="${xkbDir}"

        layout=${lib.escapeShellArg sel.xkb.layout}
        variant=${lib.escapeShellArg sel.xkb.variant}
        name=${lib.escapeShellArg sel.console}

        if [ -n "$variant" ]; then
          ckbcomp -I "$XKB_DIR" -layout "$layout" -variant "$variant" > "$name.map"
        else
          ckbcomp -I "$XKB_DIR" -layout "$layout" > "$name.map"
        fi

        gzip -9c "$name.map" > "$out/share/kbd/keymaps/custom/$name.map.gz"
        rm -f "$name.map"
      '';
in
{
  options.my.keyboard = {
    enable = lib.mkEnableOption "single keyboard preset applied to console and XKB";
    preset = lib.mkOption {
      type = lib.types.enum presets;
      default = "qwerty";
      description = "Keyboard layout preset for initrd, TTY, login, and sessions.";
    };
  };

  config = lib.mkMerge [
    {
      my.keyboard.enable = lib.mkDefault (
        lib.attrByPath [ "my" "install" "keyboard" "enable" ] true config
      );
      my.keyboard.preset = lib.mkDefault (
        lib.attrByPath [ "my" "install" "keyboard" "preset" ] "qwerty" config
      );
    }
    (lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          console.earlySetup = true;
          console.keyMap = consoleKeyMap;

          services.xserver.xkb = {
            layout = sel.xkb.layout;
            variant = sel.xkb.variant;
          }
          // lib.optionalAttrs (sel.xkb.options != "") {
            options = sel.xkb.options;
          };

          environment.sessionVariables = sessionVars;
        }
        (lib.mkIf config.services.displayManager.sddm.enable {
          services.xserver.displayManager.setupCommands = lib.mkAfter ''
            ${setxkbmapCmd}
          '';
        })
        (lib.mkIf sel.needsCustomXkb {
          console.packages = [
            pkgs.kbd
            mkConsoleKeymapsPkg
          ];
        })
        (lib.mkIf (sel.needsCustomXkb && symbolExists) {
          services.xserver.extraLayouts = {
            "${sel.xkb.layout}" = customLayouts.${sel.xkb.layout};
          };
        })
        {
          assertions = [
            {
              assertion = !(sel.needsCustomXkb && !symbolExists);
              message = "keyboard: preset \"${cfg.preset}\" requires XKB symbols under ${
                if symbolPath == null then "modules/core/xkb/symbols" else symbolPath
              }.";
            }
          ];
        }
      ]
    ))
  ];
}
