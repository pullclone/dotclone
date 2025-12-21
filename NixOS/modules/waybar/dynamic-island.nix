{ config, pkgs, lib, ... }:

let
  cfg = config.my.desktop;

  pythonEnv = pkgs.python311.withPackages (ps: with ps; [
    pygobject3
    dbus-python
  ]);

  dynamicIslandScript = pkgs.writeScriptBin "waybar-dynamic-island" ''
    #!${pythonEnv}/bin/python

    import json
    import sys
    import signal
    import gi
    from gi.repository import GLib

    gi.require_version('Playerctl', '2.0')
    from gi.repository import Playerctl

    # --- Configuration ---
    def output(text, css_class="normal", tooltip=""):
        data = {
            "text": text,
            "class": css_class,
            "tooltip": tooltip
        }
        print(json.dumps(data), flush=True)

    # --- State ---
    class State:
        media = None

    state = State()

    # --- Media Handler ---
    def on_metadata(player, metadata):
        if "xesam:artist" in metadata.keys() and "xesam:title" in metadata.keys():
            artist = metadata["xesam:artist"][0]
            title = metadata["xesam:title"]
            state.media = f"{artist} - {title}"
            update(player)

    def on_play(player, status):
        update(player)

    def on_pause(player, status):
        update(player)

    def update(player):
        css_class = "normal"
        text = ""

        if state.media:
            text = f"  {state.media}"
            try:
                # Some players might not report status correctly immediately
                if player.props.status == "Playing":
                    css_class = "playing"
                else:
                    css_class = "paused"
            except:
                pass

        if not text:
            text = ""
            css_class = "none"

        output(text, css_class)

    # --- Main Loop ---
    if __name__ == "__main__":
        manager = Playerctl.PlayerManager()

        def on_name_appeared(manager, name):
            player = Playerctl.Player.new_from_name(name)
            player.connect('metadata', on_metadata)
            player.connect('playback-status::playing', on_play)
            player.connect('playback-status::paused', on_pause)
            manager.manage_player(player)

        manager.connect('name-appeared', on_name_appeared)

        # Start looking for players
        for name in manager.props.player_names:
            on_name_appeared(manager, name)

        # Initial clear
        output("", "none")

        loop = GLib.MainLoop()
        try:
            loop.run()
        except KeyboardInterrupt:
            pass
  '';

  # Toolbar Expander Logic
  expandScript = pkgs.writeShellScriptBin "waybar-expand" ''
    #!/usr/bin/env bash
    LOCK="/tmp/waybar_expand_state"

    cmd="$1"

    case "$cmd" in
        "toggle")
            if [ -f "$LOCK" ]; then
                rm "$LOCK"
            else
                touch "$LOCK"
            fi
            # Signal Waybar to reload custom modules (Signal 8)
            pkill -RTMIN+8 waybar
            ;;
        "check")
            if [ -f "$LOCK" ]; then
                echo "expanded"
            else
                echo "collapsed"
            fi
            ;;
        *)
            echo "Usage: waybar-expand [toggle|check]"
            ;;
    esac
  '';

in
{
  config = lib.mkIf (cfg.panel == "waybar") {
    home.packages = [
      dynamicIslandScript
      expandScript

      # Runtime dependencies
      pkgs.playerctl
      pkgs.gobject-introspection
    ];
  };
}
