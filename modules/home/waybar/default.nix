{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.my.desktop;
in
{
  imports = [
    ./scripts.nix
    ./dynamic-island.nix
  ];

  config = lib.mkIf (cfg.panel == "waybar") {

    # 1. Shell Environment
    home.sessionVariables = {
      LAUNCHER_CMD = "wofi --show drun";
    };

    # 2. Required Packages
    home.packages = with pkgs; [
      waybar
      wofi
      networkmanagerapplet
      swww
      mako
      grim
      slurp
      libnotify
      wl-clipboard
      jq
      socat
    ];

    # 3. Wofi Configuration
    programs.wofi = {
      enable = true;
      settings = {
        width = 400;
        height = 250;
        location = "center";
        show = "drun";
        prompt = "Search...";
        filter_rate = 100;
        allow_markup = true;
        no_actions = true;
        halign = "fill";
        orientation = "vertical";
        content_halign = "fill";
        insensitive = true;
        allow_images = true;
        image_size = 40;
        gtk_dark = true;
      };
      style = ''
        window {
            margin: 0px;
            border: 5px solid #f5c2e7;
            background-color: #f5c2e7;
            border-radius: 15px;
        }
        #input {
            padding: 4px;
            margin: 4px;
            padding-left: 20px;
            border: none;
            color: #fff;
            font-weight: bold;
            background-color: #fff;
            background: linear-gradient(90deg, rgba(203,166,247,1) 0%, rgba(245,194,231,1) 100%);
            outline: none;
            border-radius: 15px;
            margin: 10px;
            margin-bottom: 2px;
        }
        #input:focus {
            border: 0px solid #fff;
            margin-bottom: 0px;
        }
        #inner-box {
            margin: 4px;
            border: 10px solid #fff;
            color: #cba6f7;
            font-weight: bold;
            background-color: #fff;
            border-radius: 15px;
        }
        #outer-box {
            margin: 0px;
            border: none;
            border-radius: 15px;
            background-color: #fff;
        }
        #scroll {
            margin-top: 5px;
            border: none;
            border-radius: 15px;
            margin-bottom: 5px;
        }
        #text:selected {
            color: #fff;
            margin: 0px 0px;
            border: none;
            border-radius: 15px;
        }
        #entry {
            margin: 0px 0px;
            border: none;
            border-radius: 15px;
            background-color: transparent;
        }
        #entry:selected {
            margin: 0px 0px;
            border: none;
            border-radius: 15px;
            background: linear-gradient(45deg, rgba(203,166,247,1) 30%, rgba(245,194,231,1) 100%);
        }
      '';
    };

    # 4. Waybar Configuration
    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 50;
          spacing = 5;
          margin-bottom = -11;

          modules-left = [ "niri/workspaces" ];
          modules-center = [ "custom/dynamic_pill" ];
          modules-right = [
            "temperature"
            "network"
            "battery"
            "custom/screenshot"
            "custom/cycle_wall"
            "custom/expand"
            "cpu"
            "clock"
          ];

          "niri/workspaces" = {
            format = "{icon}";
            "format-icons" = {
              "active" = "";
              "default" = "";
            };
          };

          "clock" = {
            "tooltip-format" = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            interval = 60;
            format = "{:%I:%M}";
            "max-length" = 25;
          };

          "cpu" = {
            interval = 1;
            format = "{icon0} {icon1} {icon2} {icon3}";
            "format-icons" = [
              "▁"
              "▂"
              "▃"
              "▄"
              "▅"
              "▆"
              "▇"
              "█"
            ];
          };

          "memory" = {
            format = "{}% ";
          };

          "temperature" = {
            "critical-threshold" = 80;
            "format-critical" = "{temperatureC}°C";
            format = "";
          };

          "battery" = {
            states = {
              warning = 50;
              critical = 20;
            };
            format = "{icon}";
            "format-charging" = "";
            "format-plugged" = "";
            "format-icons" = [
              ""
              ""
              ""
              ""
              ""
            ];
          };

          "network" = {
            "format-wifi" = "";
            "format-ethernet" = "";
            "tooltip-format" = "via {gwaddr} {ifname}";
            "format-linked" = "";
            "format-disconnected" = "wifi";
            "format-alt" = "   ";
          };

          "pulseaudio" = {
            format = "{format_source}";
            "on-click" = "pavucontrol";
          };

          "tray" = {
            spacing = 10;
          };

          # CUSTOM MODULES
          "custom/dynamic_pill" = {
            "return-type" = "json";
            "exec" = "waybar-dynamic-island";
            "escape" = true;
          };

          "custom/screenshot" = {
            "format" = "";
            "on-click" = "waybar-screenshot full";
            "exec-if" = "test -f /tmp/waybar_expand_state";
            "signal" = 8;
          };

          "custom/cycle_wall" = {
            format = "{}";
            "on-click" = "waybar-cycle-wall";
            "exec-if" = "test -f /tmp/waybar_expand_state";
            "signal" = 8;
          };

          "custom/expand" = {
            "format" = "";
            "format-icons" = {
              "expanded" = "";
              "collapsed" = "";
            };
            exec = "waybar-expand check";
            "on-click" = "waybar-expand toggle";
            "signal" = 8;
          };
        };
      };

      # 5. Waybar Styles
      style = ''
        * {
            font-family: "FiraCode Nerd Font", "Noto Sans", "FontAwesome", Roboto, Helvetica, Arial, sans-serif;
            font-size: 13px;
        }

        #clock,
        #battery,
        #cpu,
        #memory,
        #disk,
        #temperature,
        #backlight,
        #network,
        #pulseaudio,
        #custom-media,
        #tray,
        #mode,
        #idle_inhibitor,
        #custom-expand,
        #custom-cycle_wall,
        #custom-screenshot,
        #custom-dynamic_pill,
        #mpd {
            padding: 0 10px;
            border-radius: 15px;
            background: #11111b;
            color: #b4befe;
            box-shadow: rgba(0, 0, 0, 0.116) 2 2 5 2px;
            margin-top: 10px;
            margin-bottom: 10px;
            margin-right: 10px;
        }

        window#waybar {
            background-color: transparent;
        }

        #custom-dynamic_pill label {
            color: #11111b;
            font-weight: bold;
        }

        #custom-dynamic_pill.paused label {
            color: #89b4fa;
            font-weight: bolder;
        }

        /* Your workspaces style */
        #workspaces button {
            box-shadow: rgba(0, 0, 0, 0.116) 2 2 5 2px;
            background-color: #11111b;
            border-radius: 15px;
            margin-right: 10px;
            padding: 10px 4px 10px 4px; /* Fixed padding for Niri icons */
            font-weight: bolder;
            color: #89b4fa;
            transition: all 0.5s cubic-bezier(.55,-0.68,.48,1.68);
        }

        #workspaces button.active {
            padding-right: 20px;
            box-shadow: rgba(0, 0, 0, 0.288) 2 2 5 2px;
            padding-left: 20px;
            padding-bottom: 3px;
            background: rgb(203,166,247);
            background: radial-gradient(circle, rgba(203,166,247,1) 0%, rgba(193,168,247,1) 12%, rgba(249,226,175,1) 19%, rgba(189,169,247,1) 20%, rgba(182,171,247,1) 24%, rgba(198,255,194,1) 36%, rgba(177,172,247,1) 37%, rgba(170,173,248,1) 48%, rgba(255,255,255,1) 52%, rgba(166,174,248,1) 52%, rgba(160,175,248,1) 59%, rgba(148,226,213,1) 66%, rgba(155,176,248,1) 67%, rgba(152,177,248,1) 68%, rgba(205,214,244,1) 77%, rgba(148,178,249,1) 78%, rgba(144,179,250,1) 82%, rgba(180,190,254,1) 83%, rgba(141,179,250,1) 90%, rgba(137,180,250,1) 100%);
            background-size: 400% 400%;
            animation: gradient_f 20s ease-in-out infinite;
        }

        @keyframes gradient {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 30%; }
            100% { background-position: 0% 50%; }
        }

        @keyframes gradient_f {
            0% { background-position: 0% 200%; }
            50% { background-position: 200% 0%; }
            100% { background-position: 400% 200%; }
        }

        @keyframes gradient_f_nh {
            0% { background-position: 0% 200%; }
            100% { background-position: 200% 200%; }
        }

        #custom-dynamic_pill.low {
            background: linear-gradient(52deg, rgba(148,226,213,1) 0%, rgba(137,220,235,1) 19%, rgba(116,199,236,1) 43%, rgba(137,180,250,1) 56%, rgba(180,190,254,1) 80%, rgba(186,187,241,1) 100%);
            background-size: 300% 300%;
            text-shadow: 0 0 5px rgba(0, 0, 0, 0.377);
            animation: gradient 15s ease infinite;
            font-weight: bolder;
            color: #fff;
        }
        #custom-dynamic_pill.normal {
            background: radial-gradient(circle, rgba(148,226,213,1) 0%, rgba(156,227,191,1) 21%, rgba(249,226,175,1) 34%, rgba(158,227,186,1) 35%, rgba(163,227,169,1) 59%, rgba(148,226,213,1) 74%, rgba(164,227,167,1) 74%, rgba(166,227,161,1) 100%);
            background-size: 400% 400%;
            animation: gradient_f 4s ease infinite;
            text-shadow: 0 0 5px rgba(0, 0, 0, 0.377);
            font-weight: bolder;
            color: #fff;
        }
        #custom-dynamic_pill.critical {
            background: linear-gradient(52deg, rgba(235,160,172,1) 0%, rgba(243,139,168,1) 30%, rgba(231,130,132,1) 48%, rgba(250,179,135,1) 77%, rgba(249,226,175,1) 100%);
            background-size: 300% 300%;
            animation: gradient 15s cubic-bezier(.55,-0.68,.48,1.68) infinite;
            text-shadow: 0 0 5px rgba(0, 0, 0, 0.377);
            font-weight: bolder;
            color: #fff;
        }
        #custom-dynamic_pill.playing {
            background: radial-gradient(circle, rgba(137,180,250,120) 0%, rgba(142,179,250,120) 6%, rgba(148,226,213,1) 14%, rgba(147,178,250,1) 14%, rgba(155,176,249,1) 18%, rgba(245,194,231,1) 28%, rgba(158,175,249,1) 28%, rgba(181,170,248,1) 58%, rgba(205,214,244,1) 69%, rgba(186,169,248,1) 69%, rgba(195,167,247,1) 72%, rgba(137,220,235,1) 73%, rgba(198,167,247,1) 78%, rgba(203,166,247,1) 100%);
            background-size: 400% 400%;
            animation: gradient_f 9s cubic-bezier(.72,.39,.21,1) infinite;
            text-shadow: 0 0 5px rgba(0, 0, 0, 0.377);
            font-weight: bold;
            color: #fff;
        }

        #custom-screenshot {
            background: #11111b; color: #89b4fa; font-weight: bolder; padding: 5px 20px; border-radius: 15px;
        }

        #custom-cycle_wall {
            background: linear-gradient(45deg, rgba(245,194,231,1) 0%, rgba(203,166,247,1) 0%, rgba(243,139,168,1) 13%, rgba(235,160,172,1) 26%, rgba(250,179,135,1) 34%, rgba(249,226,175,1) 49%, rgba(166,227,161,1) 65%, rgba(148,226,213,1) 77%, rgba(137,220,235,1) 82%, rgba(116,199,236,1) 88%, rgba(137,180,250,1) 95%);
            color: #fff;
            background-size: 500% 500%;
            animation: gradient 7s linear infinite;
            font-weight: bolder;
            border-radius: 15px;
        }

        #clock {
            background: linear-gradient(118deg, rgba(205,214,244,1) 5%, rgba(243,139,168,1) 5%, rgba(243,139,168,1) 20%, rgba(205,214,244,1) 20%, rgba(205,214,244,1) 40%, rgba(243,139,168,1) 40%, rgba(243,139,168,1) 60%, rgba(205,214,244,1) 60%, rgba(205,214,244,1) 80%, rgba(243,139,168,1) 80%, rgba(243,139,168,1) 95%, rgba(205,214,244,1) 95%);
            background-size: 200% 300%;
            animation: gradient_f_nh 4s linear infinite;
            margin-right: 25px;
            color: #fff;
            text-shadow: 0 0 5px rgba(0, 0, 0, 0.377);
            font-size: 15px;
            padding-top: 5px;
            padding-right: 21px;
            font-weight: bolder;
            padding-left: 20px;
        }

        #battery.charging, #battery.plugged { background-color: #94e2d5; }
        #battery { background-color: #11111b; color: #a6e3a1; font-weight: bolder; font-size: 20px; padding: 0 15px; }

        @keyframes blink { to { background-color: #f9e2af; color: #96804e; } }
        #battery.critical:not(.charging) {
            background-color: #f38ba8; color: #bf5673;
            animation: blink 0.5s linear infinite alternate;
        }

        #cpu label { color: #89dceb; }
        #cpu { background: radial-gradient(circle, rgba(30,30,46,1) 30%, rgba(17,17,27,1) 100%); color: #89b4fa; }

        #memory { background-color: #cba6f7; color: #9a75c7; font-weight: bolder; }
        #disk { color: #964B00; }
        #backlight { color: #90b1b1; }

        #network { color: #000; }
        #network.disabled { background-color: #45475a; }
        #network.disconnected {
            background: linear-gradient(45deg, rgba(243,139,168,1) 0%, rgba(250,179,135,1) 100%);
            color: #fff; font-weight: bolder; padding-top: 3px; padding-right: 11px;
        }
        #network.linked, #network.wifi { background-color: #a6e3a1; }
        #network.ethernet { background-color: #f9e2af; }

        #pulseaudio { background-color: #fab387; color: #bf7d54; font-weight: bolder; }
        #pulseaudio.muted { background-color: #90b1b1; }

        #temperature { background-color: #f9e2af; color: #96804e; }
        #temperature.critical { background-color: #f38ba8; color: #bf5673; }

        #tray { background-color: #2980b9; }
        #tray > .passive { -gtk-icon-effect: dim; }
        #tray > .needs-attention { -gtk-icon-effect: highlight; background-color: #eb4d4b; }
      '';
    };

    # 6. Swaylock Configuration
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        clock = true;
        indicator = true;
        indicator-radius = 80;
        indicator-thickness = 5;
        effect-blur = "10x7";
        effect-vignette = "0.2:0.2";

        # Colors
        ring-color = "11111b";
        key-hl-color = "f5c2e7";
        line-color = "313244";
        inside-color = "11111b";
        separator-color = "00000000";

        inside-wrong-color = "f38ba8";
        ring-wrong-color = "11111b";

        inside-clear-color = "a6e3a1";
        ring-clear-color = "11111b";

        inside-ver-color = "89b4fa";
        ring-ver-color = "11111b";

        text-color = "f5c2e7";

        fade-in = 0.1;
      };
    };

  };
}
