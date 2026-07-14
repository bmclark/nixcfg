# Wayland ecosystem module providing Hyprland companion services and switchable theming.
{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
with lib; let
  cfg = config.features.desktop.wayland;
  palette = theme.palette;
  rgba = color: alpha:
    let
      hex = lib.removePrefix "#" color;
      hexMap = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
        "A" = 10;
        "B" = 11;
        "C" = 12;
        "D" = 13;
        "E" = 14;
        "F" = 15;
      };
      charToInt = c:
        if builtins.hasAttr c hexMap
        then hexMap.${c}
        else throw "Invalid hexadecimal digit: ${c}";
      pairToInt = pair:
        let first = builtins.substring 0 1 pair;
            second = builtins.substring 1 1 pair;
        in charToInt first * 16 + charToInt second;
      channel = index: pairToInt (builtins.substring index 2 hex);
      alphaInt = pairToInt alpha;
      alphaFloat = alphaInt / 255.0;
    in
      "rgba(${builtins.toString (channel 0)}, ${builtins.toString (channel 2)}, ${builtins.toString (channel 4)}, ${builtins.toString alphaFloat})";
in {
  options.features.desktop.wayland.enable =
    mkEnableOption "wayland extra tools and config";

  config = mkIf cfg.enable {
    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    # --- Wayland Ecosystem Packages -----------------------------------------
    home.packages = with pkgs; [
      # Screenshots & capture
      cliphist
      grim
      slurp
      swappy
      wf-recorder
      wl-mirror
      wl-clipboard
      hyprpicker

      # Input & remote tooling
      wtype
      ydotool
      waypipe

      # Session utilities
      hyprlock
      wlogout
      libnotify # notification testing via notify-send
      pavucontrol # PipeWire / PulseAudio mixer
      blueman # Bluetooth device manager
      polkit_gnome # authentication agent binary
      qt6.qtwayland
      wttrbar
      awww # animated wallpaper daemon with transition effects (swww renamed upstream)
      playerctl # media control for mpris waybar module

      # Thunar extensions for archives and removable media
      thunar
      thunar-archive-plugin
      thunar-volman
      zathura
      tesseract
    ];

    # --- Wallpapers (awww) ---------------------------------------------------
    # awww (formerly swww) provides animated transitions between wallpapers.
    # Wallpaper dir: ~/Pictures/papes/{sfw,nsfw}
    # Toggle: `wallpaper-mode sfw` or `wallpaper-mode nsfw`
    # Random: `wallpaper-random` picks a random wallpaper from active mode
    services.hyprpaper.enable = false;

    # Wallpaper mode scripts
    home.file.".local/bin/wallpaper-mode" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Switch wallpaper mode between sfw/nsfw
        MODE=''${1:-sfw}
        PAPES_DIR="$HOME/Pictures/papes/$MODE"
        STATE_FILE="$HOME/.local/state/wallpaper-mode"
        mkdir -p "$(dirname "$STATE_FILE")"

        if [[ ! -d "$PAPES_DIR" ]]; then
          notify-send "Wallpaper" "Directory not found: $PAPES_DIR" -u critical
          exit 1
        fi

        echo "$MODE" > "$STATE_FILE"
        notify-send "Wallpaper" "Mode set to $MODE"
        # Set a random wallpaper from the new mode
        exec "$HOME/.local/bin/wallpaper-random"
      '';
    };

    home.file.".local/bin/wallpaper-random" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Pick a random wallpaper from the active mode directory
        STATE_FILE="$HOME/.local/state/wallpaper-mode"
        MODE="sfw"
        [[ -f "$STATE_FILE" ]] && MODE="$(cat "$STATE_FILE")"
        PAPES_DIR="$HOME/Pictures/papes/$MODE"

        if [[ ! -d "$PAPES_DIR" ]]; then
          PAPES_DIR="$HOME/Pictures/papes/sfw"
        fi

        WALLPAPER="$(find "$PAPES_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) 2>/dev/null | shuf -n 1)"

        if [[ -n "$WALLPAPER" ]]; then
          awww img "$WALLPAPER" \
            --transition-type grow \
            --transition-pos "$(hyprctl cursorpos)" \
            --transition-duration 2 \
            --transition-fps 60
        fi
      '';
    };

    # Rotate wallpaper every 20 minutes
    systemd.user.services.wallpaper-rotate = {
      Unit.Description = "Rotate wallpaper";
      Service = {
        Type = "oneshot";
        ExecStart = "%h/.local/bin/wallpaper-random";
      };
    };
    systemd.user.timers.wallpaper-rotate = {
      Unit.Description = "Rotate wallpaper every 20 minutes";
      Timer = {
        OnUnitActiveSec = "20m";
        OnStartupSec = "20m";
      };
      Install.WantedBy = ["timers.target"];
    };

    home.file.".local/bin/wallpaper-set" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Set a specific wallpaper with transition
        if [[ -z "$1" ]]; then
          echo "Usage: wallpaper-set <path>"
          exit 1
        fi
        awww img "$1" \
          --transition-type grow \
          --transition-pos "$(hyprctl cursorpos)" \
          --transition-duration 2 \
          --transition-fps 60
      '';
    };

    home.file.".local/bin/dropdown-terminal" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Guake-style dropdown terminal using Hyprland's special workspace.
        # Sizes to top third of screen and slides down from top.

        get_addr() {
          hyprctl clients -j | ${pkgs.python3}/bin/python3 -c "
        import json, sys
        for c in json.load(sys.stdin):
            if 'special:terminal' in str(c.get('workspace', {})):
                print(c['address']); break
        "
        }

        ADDR=$(get_addr)
        if [[ -n "$ADDR" ]]; then
          hyprctl dispatch togglespecialworkspace terminal
        else
          hyprctl dispatch togglespecialworkspace terminal
          sleep 0.4
          ADDR=$(get_addr)
          if [[ -n "$ADDR" ]]; then
            hyprctl --batch "\
              dispatch floatwindow address:$ADDR;\
              dispatch resizewindowpixel exact 1920 360,address:$ADDR;\
              dispatch movewindowpixel exact 0 0,address:$ADDR"
          fi
        fi
      '';
    };

    home.file.".local/bin/cliphist-wofi" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        cliphist list | wofi --dmenu --prompt "Clipboard" | cliphist decode | wl-copy
      '';
    };

    home.file.".local/bin/copy-path" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        target="''${1:?Usage: copy-path <path>}"
        realpath "$target" | tr -d '\n' | wl-copy
        notify-send "Path copied" "$(realpath "$target")"
      '';
    };

    home.file.".local/bin/thunar-open-terminal" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        target="''${1:-$PWD}"
        if [[ -f "$target" ]]; then
          target="$(dirname "$target")"
        fi
        exec ghostty -e sh -lc 'cd "$1" && exec "${SHELL:-zsh}"' sh "$target"
      '';
    };

    home.file.".local/bin/screenshot-area-annotate" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        target="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d-%H%M%S).png"
        mkdir -p "$(dirname "$target")"
        grim -g "$(slurp)" - | swappy -f - -o "$target"
        notify-send "Screenshot" "Saved to $target"
      '';
    };

    home.file.".local/bin/ocr-image" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        image="''${1:?Usage: ocr-image <image>}"
        text="$(tesseract "$image" stdout 2>/dev/null)"
        printf '%s\n' "$text"
        printf '%s' "$text" | wl-copy
        notify-send "OCR" "Copied text from $(basename "$image")"
      '';
    };

    home.file.".local/bin/ocr-pdf" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        pdf="''${1:?Usage: ocr-pdf <pdf> [page] }"
        page="''${2:-1}"
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        pdftoppm -f "$page" -l "$page" -png "$pdf" "$tmpdir/page" >/dev/null
        image="$(find "$tmpdir" -name 'page-*.png' | head -n 1)"
        [[ -n "$image" ]] || { echo "Failed to render PDF page $page" >&2; exit 1; }
        text="$(tesseract "$image" stdout 2>/dev/null)"
        printf '%s\n' "$text"
        printf '%s' "$text" | wl-copy
        notify-send "OCR" "Copied text from $(basename "$pdf") page $page"
      '';
    };

    home.file.".local/bin/ocr-screenshot" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        tmpfile="$(mktemp --suffix=.png)"
        trap 'rm -f "$tmpfile"' EXIT
        grim -g "$(slurp)" "$tmpfile"
        text="$(tesseract "$tmpfile" stdout 2>/dev/null)"
        printf '%s\n' "$text"
        printf '%s' "$text" | wl-copy
        notify-send "OCR" "Copied text from selected screen region"
      '';
    };

    xdg.configFile."Thunar/uca.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <actions>
        <action>
          <icon>utilities-terminal</icon>
          <name>Open Terminal Here</name>
          <submenu></submenu>
          <unique-id>171001000000001</unique-id>
          <command>$HOME/.local/bin/thunar-open-terminal %f</command>
          <description>Open Ghostty in the selected directory</description>
          <patterns>*</patterns>
          <directories/>
        </action>
        <action>
          <icon>edit-copy</icon>
          <name>Copy Path</name>
          <submenu></submenu>
          <unique-id>171001000000002</unique-id>
          <command>$HOME/.local/bin/copy-path %f</command>
          <description>Copy the selected path to the clipboard</description>
          <patterns>*</patterns>
          <directories/>
          <audio-files/>
          <image-files/>
          <other-files/>
          <text-files/>
          <video-files/>
        </action>
        <action>
          <icon>accessories-text-editor</icon>
          <name>OCR Image To Clipboard</name>
          <submenu></submenu>
          <unique-id>171001000000003</unique-id>
          <command>$HOME/.local/bin/ocr-image %f</command>
          <description>Extract text from the selected image</description>
          <patterns>*.png;*.jpg;*.jpeg;*.webp;*.tif;*.tiff;*.bmp;</patterns>
          <image-files/>
        </action>
        <action>
          <icon>x-office-document</icon>
          <name>OCR PDF First Page</name>
          <submenu></submenu>
          <unique-id>171001000000004</unique-id>
          <command>$HOME/.local/bin/ocr-pdf %f 1</command>
          <description>Extract text from the first page of the selected PDF</description>
          <patterns>*.pdf;</patterns>
          <other-files/>
        </action>
      </actions>
    '';

    # --- Lock Screen (hyprlock) -----------------------------------------------
    # Dracula-themed lock screen with clock, input field, and date.
    xdg.configFile."hypr/hyprlock.conf".text = ''
      background {
        monitor =
        path = screenshot
        blur_passes = 3
        blur_size = 6
        noise = 0.02
        contrast = 0.9
        brightness = 0.6
        vibrancy = 0.2
      }

      input-field {
        monitor =
        size = 300, 50
        outline_thickness = 2
        dots_size = 0.25
        dots_spacing = 0.15
        dots_center = true
        outer_color = rgb(${lib.removePrefix "#" palette.purple})
        inner_color = rgb(${lib.removePrefix "#" palette.selection})
        font_color = rgb(${lib.removePrefix "#" palette.fg})
        fade_on_empty = true
        placeholder_text = <span foreground="##6272a4">Password...</span>
        hide_input = false
        check_color = rgb(${lib.removePrefix "#" palette.cyan})
        fail_color = rgb(${lib.removePrefix "#" palette.red})
        fail_text = <i>$FAIL</i>
        position = 0, -20
        halign = center
        valign = center
      }

      label {
        monitor =
        text = $TIME
        color = rgb(${lib.removePrefix "#" palette.fg})
        font_size = 72
        font_family = JetBrainsMono Nerd Font
        position = 0, 120
        halign = center
        valign = center
      }

      label {
        monitor =
        text = cmd[update:3600000] date +"%A, %B %d"
        color = rgb(${lib.removePrefix "#" palette.comment})
        font_size = 18
        font_family = JetBrainsMono Nerd Font
        position = 0, 60
        halign = center
        valign = center
      }

      label {
        monitor =
        text = $USER
        color = rgb(${lib.removePrefix "#" palette.purple})
        font_size = 14
        font_family = JetBrainsMono Nerd Font
        position = 0, -80
        halign = center
        valign = center
      }
    '';

    # --- Idle Management ----------------------------------------------------
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
        listener = [
          # Dim screen after 5 minutes
          {
            timeout = 300;
            on-timeout = "brightnessctl -s set 10%";
            on-resume = "brightnessctl -r";
          }
          # Lock after 15 minutes
          {
            timeout = 900;
            on-timeout = "pidof hyprlock || hyprlock";
          }
          # DPMS off after 20 minutes
          {
            timeout = 1200;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    }; # Dims after 5 min, locks after 15 min, blanks displays after 20 min.

    services.cliphist.enable = true;

    # --- AltTab Window Switcher (hyprshell) -----------------------------------
    services.hyprshell = {
      enable = true;
      systemd.enable = true;
      settings = {
        version = 3;
        windows = {
          scale = 0.3;
          items_per_row = 3;
          switch = {
            modifier = "alt";
            filter_by = [];
            switch_workspaces = true;
          };
        };
      };
    };

    # --- Application Launcher -----------------------------------------------
    programs.wofi = {
      enable = true;
      settings = {
        allow_markup = true;
        allow_images = true; # show app icons
        image_size = 24;
        width = 500;
        height = 400;
        location = "center";
        prompt = "  Search";
        hide_scroll = true;
        insensitive = true;
        term = "ghostty";
        columns = 1;
        matching = "fuzzy";
      };
      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 14px;
        }

        window {
          background-color: ${rgba palette.bg "e6"};
          border-radius: 12px;
          border: 2px solid ${palette.purple};
          padding: 16px;
        }

        #input {
          margin-bottom: 12px;
          padding: 10px 14px;
          border-radius: 8px;
          border: 1px solid ${palette.comment};
          background-color: ${rgba palette.selection "cc"};
          color: ${palette.fg};
          transition: border-color 0.2s ease;
        }

        #input:focus {
          border-color: ${palette.purple};
        }

        #inner-box,
        #outer-box,
        #scroll {
          margin: 0;
          padding: 0;
          background-color: transparent;
        }

        #img {
          margin-right: 8px;
        }

        #entry {
          padding: 8px 10px;
          border-radius: 8px;
          color: ${palette.fg};
          transition: background-color 0.15s ease;
        }

        #entry:selected {
          background-color: ${rgba palette.purple "dd"};
          color: ${palette.bg};
        }

        #text {
          color: inherit;
        }

        #text:selected {
          color: ${palette.bg};
        }
      '';
    }; # Dracula-themed app launcher with icons (Super+D).

    # --- Notifications ------------------------------------------------------
    services.dunst = {
      enable = true;
      settings = {
        global = {
          # Appearance
          frame_color = palette.purple;
          separator_color = "frame";
          origin = "top-right";
          offset = "10x10";
          width = "(280, 400)";
          corner_radius = 10;
          padding = 14;
          horizontal_padding = 14;
          text_icon_padding = 10;
          font = "JetBrainsMono Nerd Font 10";
          background = palette.bg;
          foreground = palette.fg;

          # Layout
          alignment = "left";
          icon_position = "left";
          max_icon_size = 48;
          min_icon_size = 32;
          markup = "full";
          format = "<b>%s</b>\\n%b";
          word_wrap = true;
          ellipsize = "end";

          # Behavior
          follow = "mouse";
          show_age_threshold = 60;
          stack_duplicates = true;
          hide_duplicate_count = false;
          sort = true;
          idle_threshold = 120;

          # History
          sticky_history = true;
          history_length = 50;

          # Mouse actions
          mouse_left_click = "do_action, close_current";
          mouse_middle_click = "close_all";
          mouse_right_click = "close_current";

          # Progress bar (volume, brightness via notify-send)
          progress_bar = true;
          progress_bar_height = 8;
          progress_bar_frame_width = 1;
          progress_bar_min_width = 150;
          progress_bar_max_width = 300;
          progress_bar_corner_radius = 4;
        };
        urgency_low = {
          timeout = 5;
          background = palette.bg;
          foreground = palette.comment;
          frame_color = palette.selection;
        };
        urgency_normal = {
          timeout = 8;
          background = palette.bg;
          foreground = palette.fg;
          frame_color = palette.purple;
        };
        urgency_critical = {
          timeout = 0;
          background = palette.bg;
          foreground = palette.fg;
          frame_color = palette.red;
        };

        # Per-app rules
        discord = {
          appname = "Discord";
          frame_color = palette.pink;
          timeout = 6;
        };
        spotify = {
          appname = "Spotify";
          frame_color = palette.green;
          timeout = 4;
        };
        volume = {
          appname = "changevolume";
          history_ignore = true;
          timeout = 2;
        };
        brightness = {
          appname = "changebrightness";
          history_ignore = true;
          timeout = 2;
        };
      };
    }; # Dracula-styled notifications with progress bars, history, and per-app rules.

    # --- Automounting & Desktop Services ------------------------------------
    services.udiskie = {
      enable = true;
      automount = true;
      tray = "auto";
      notify = true;
      settings = {
        program_options = {
          automount = true;
          notify = true;
          tray = "auto";
        };
      };
    }; # Automount removable media with per-user ownership and tray icon.

    systemd.user.services."polkit-gnome-authentication-agent-1" = {
      Unit = {
        Description = "Polkit Authentication Agent";
        After = ["graphical-session.target" "hyprland-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        Type = "simple";
      };
      Install = {
        WantedBy = ["graphical-session.target" "hyprland-session.target"];
      };
    }; # Authentication dialogs for privileged actions.

    # --- Status Bar ---------------------------------------------------------
    programs.waybar = {
      enable = true;
      style = ''
        * {
          border: none;
          border-radius: 0;
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 13px;
          min-height: 0;
          transition: all 0.2s ease;
        }

        window#waybar {
          background: transparent;
          color: ${palette.fg};
        }

        tooltip {
          background: ${palette.bg};
          border-radius: 10px;
          border: 1px solid ${palette.selection};
          color: ${palette.fg};
        }

        #workspaces button {
          padding: 6px 10px;
          color: ${palette.comment};
          margin: 3px 3px;
          border-radius: 8px;
          background: ${rgba palette.bg "cc"};
        }

        #workspaces button.active {
          color: ${palette.bg};
          background: ${palette.purple};
        }

        #workspaces button.focused {
          color: ${palette.bg};
          background: ${palette.pink};
        }

        #workspaces button.urgent {
          color: ${palette.bg};
          background: ${palette.red};
          animation: urgentPulse 1s ease-in-out infinite alternate;
        }

        @keyframes urgentPulse {
          to { background: ${palette.orange}; }
        }

        #workspaces button:hover {
          background: ${palette.selection};
          color: ${palette.fg};
        }

        #custom-weather,
        #window,
        #clock,
        #battery,
        #cpu,
        #memory,
        #backlight,
        #mpris,
        #wireplumber,
        #network,
        #bluetooth,
        #workspaces,
        #tray {
          background: ${rgba palette.bg "cc"};
          padding: 4px 12px;
          margin: 3px 3px;
          border-radius: 10px;
          border: 1px solid ${rgba palette.selection "aa"};
        }

        /* Hover glow on all modules */
        #custom-weather:hover,
        #clock:hover,
        #battery:hover,
        #cpu:hover,
        #memory:hover,
        #backlight:hover,
        #mpris:hover,
        #wireplumber:hover,
        #network:hover,
        #bluetooth:hover {
          background: ${rgba palette.selection "dd"};
          border-color: ${palette.purple};
        }

        #tray {
          margin-right: 12px;
        }

        #clock {
          color: ${palette.orange};
        }

        #wireplumber {
          color: ${palette.pink};
        }

        #battery {
          color: ${palette.green};
        }

        #battery.warning {
          color: ${palette.yellow};
        }

        #battery.critical {
          color: ${palette.red};
          animation: urgentPulse 1s ease-in-out infinite alternate;
        }

        #network {
          color: ${palette.cyan};
        }

        #network.disconnected {
          color: ${palette.red};
        }

        #bluetooth {
          color: ${palette.purple};
        }

        #custom-weather {
          color: ${palette.yellow};
        }

        #cpu {
          color: ${palette.cyan};
        }

        #memory {
          color: ${palette.green};
        }

        #backlight {
          color: ${palette.yellow};
        }

        #mpris {
          color: ${palette.pink};
        }
      '';
      settings = {
        mainbar = {
          layer = "top";
          position = "top";
          mode = "dock";
          exclusive = true;
          passthrough = false;
          gtk-layer-shell = true;
          height = 0;
          modules-left = ["hyprland/workspaces" "mpris"];
          modules-center = ["hyprland/window"];
          modules-right = ["cpu" "memory" "backlight" "bluetooth" "network" "wireplumber" "battery" "tray" "custom/weather" "clock"];

          "hyprland/window" = {
            format = "{}";
            separate-outputs = true;
          };
          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
            on-click = "activate";
            format = "{icon}";
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
            format-icons = {
              "1" = "";
              "2" = "";
              "3" = "";
              "4" = "";
              "5" = "";
              "6" = "";
              "7" = "";
            };
            persistent_workspaces = {
              "1" = [];
              "2" = [];
              "3" = [];
              "4" = [];
            };
          };
          "custom/weather" = {
            format = "{}°F";
            tooltip = true;
            interval = 3600;
            exec = ''wttrbar --location "34223" --fahrenheit --'';
            return-type = "json";
          };
          mpris = {
            format = "{player_icon} {title} - {artist}";
            format-paused = "{player_icon} {status_icon} {title} - {artist}";
            player-icons = {
              default = "▶";
              firefox = "";
              spotify = "";
            };
            status-icons = {
              paused = "⏸";
            };
            max-length = 40;
          };
          cpu = {
            format = " {usage}%";
            tooltip-format = "{avg_frequency} GHz\n{usage}% used";
            interval = 5;
            on-click = "ghostty -e btop";
          };
          memory = {
            format = " {percentage}%";
            tooltip-format = "{used:0.1f} GiB / {total:0.1f} GiB";
            interval = 10;
            on-click = "ghostty -e btop";
          };
          backlight = {
            format = " {percent}%";
            tooltip = true;
            on-scroll-up = "brightnessctl set +5%";
            on-scroll-down = "brightnessctl set 5%-";
          };
          tray = {
            icon-size = 13;
            spacing = 10;
          };
          clock = {
            format = "{:%R  %m/%d}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };
          wireplumber = {
            format = " {volume}%";
            format-muted = " Muted";
            on-click = "pavucontrol";
            on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          };
          battery = {
            format = " {capacity}%";
            format-charging = " {capacity}%";
            states = {
              warning = 30;
              critical = 15;
            };
          };
          network = {
            format-wifi = " {essid}";
            format-ethernet = " {ifname}";
            format-disconnected = " Offline";
            tooltip-format = "{ifname}: {ipaddr}";
          };
          bluetooth = {
            format = " {status}";
            format-connected = " {device_alias}";
            format-connected-battery = " {device_alias} {device_battery_percentage}%";
            tooltip-format = "{controller_alias}\n{num_connections} connected";
            on-click = "blueman-manager";
          };
        };
      };
    };

    # --- Night Light --------------------------------------------------------
    services.wlsunset = {
      enable = true;
      latitude = 27.10; # Venice, FL
      longitude = -82.45;
    };
  };
}
