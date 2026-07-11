# Hyprland window manager with full rice: switchable theme, blur, window rules,
# gestures, and workspace assignments. Aligned with ADR-003 (keyboard strategy)
# and ADR-004 (theme standardization). WM keybindings use the Hyper chord
# (CTRL+ALT+SUPER), matching macOS Karabiner and Aerospace. keyd emits this
# chord from the physical Ctrl key via the hyper:C-A-M layer.
# Config uses Hyprland 0.55.2 Lua API: hl.config({...}), hl.bind(key, hl.dsp.*).
{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
with lib; let
  cfg = config.features.desktop.hyprland;
  palette = theme.palette;
  stripHash = color: builtins.replaceStrings ["#"] [""] color;
  rgba = color: alpha: "rgba(${stripHash color}${alpha})";
  kb = import ./keybindings.nix;
  # Generate workspace window_rule entries from shared keybindings module
  workspaceWindowRules = lib.concatLists (lib.mapAttrsToList (ws: def:
    map (app: {
      name = "ws-${ws}-${builtins.replaceStrings ["."] ["_"] app}";
      match.class = "^(${app})$";
      workspace = builtins.fromJSON ws;
    }) def.linux
  ) kb.workspaces);
in {
  options.features.desktop.hyprland.enable = mkEnableOption "hyprland config";

  config = mkIf cfg.enable {
    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/keyring/ssh";
    };

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua"; # 0.55.2 Lua API: hl.config({...}), hl.bind(key, hl.dsp.*)
      systemd = {
        enable = true;
        variables = ["--all"];
      };

      settings = {
        # --- Main Config Block (→ hl.config({...})) --------------------------
        # All top-level config sections are grouped here per the 0.55.2 API.
        config = {
          xwayland.force_zero_scaling = true;

          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 1;
            layout = "dwindle";
            # Dracula palette border gradient: pink → purple
            col = {
              active_border = {
                colors = ["${rgba palette.pink "ee"}" "${rgba palette.purple "ee"}"];
                angle = 45;
              };
              inactive_border = rgba palette.comment "aa";
            };
          };

          decoration = {
            rounding = 12;
            active_opacity = 0.65;
            inactive_opacity = 0.35;
            blur = {
              enabled = true;
              size = 6;
              passes = 3;
              vibrancy = 0.20;
              contrast = 1.0;
              brightness = 0.9;
              noise = 0.01;
              xray = true; # Blurred layers (waybar) show through for glass effect
              popups = true;
              popups_ignorealpha = 0.25;
            };
            shadow = {
              enabled = true;
              range = 18;
              render_power = 3;
              offset = "0 6";
              scale = 1.0;
              color = rgba palette.bg "66";
            };
          };

          animations.enabled = true; # Curves/entries defined via extraConfig hl.curve/hl.animation

          input = {
            kb_layout = "us";
            kb_variant = "";
            kb_model = "";
            kb_rules = "";
            kb_options = ""; # Key remapping handled by keyd (CapsLock→Ctrl, Ctrl→Super)
            follow_mouse = 1;
            sensitivity = 0;
            touchpad = {
              natural_scroll = false;
              tap_to_click = true;
            };
          };

          dwindle.preserve_split = true;

          misc = {
            force_default_wallpaper = -1;
            disable_hyprland_logo = false;
          };
        };

        # --- Bezier Curves (hoisted before animations by importantPrefixes=["curve"]) ---
        # _args = two-arg form: hl.curve("name", {type, points})
        curve = [
          { _args = ["easeOutQuint"   {type = "bezier"; points = [[0.23 1.0] [0.32 1.0]];}]; }
          { _args = ["easeInOutCubic" {type = "bezier"; points = [[0.65 0.05] [0.36 1.0]];}]; }
          { _args = ["quick"          {type = "bezier"; points = [[0.15 0.0] [0.1 1.0]];}]; }
        ];

        # --- Gestures (→ hl.gesture({...})) ----------------------------------
        gesture = [
          {fingers = 3; direction = "horizontal"; action = "workspace";}
        ];

        # --- Animations (→ hl.animation({...})) ------------------------------
        animation = [
          {leaf = "global"; enabled = true; speed = 10; bezier = "default";}
          {leaf = "windowsIn"; enabled = true; speed = 6; bezier = "easeOutQuint"; style = "popin 85%";}
          {leaf = "windowsOut"; enabled = true; speed = 5; bezier = "easeInOutCubic"; style = "popin 80%";}
          {leaf = "windowsMove"; enabled = true; speed = 6; bezier = "easeInOutCubic";}
          {leaf = "border"; enabled = true; speed = 8; bezier = "easeInOutCubic";}
          {leaf = "borderangle"; enabled = true; speed = 8; bezier = "easeInOutCubic";}
          {leaf = "fadeIn"; enabled = true; speed = 6; bezier = "easeOutQuint";}
          {leaf = "fadeOut"; enabled = true; speed = 6; bezier = "quick";}
          {leaf = "layers"; enabled = true; speed = 6; bezier = "easeOutQuint";}
          {leaf = "workspaces"; enabled = true; speed = 7; bezier = "easeOutQuint"; style = "slidefade 40%";}
          {leaf = "specialWorkspace"; enabled = true; speed = 5; bezier = "easeOutQuint"; style = "slidevert";}
        ];

        # --- Layer Rules (→ hl.layer_rule({...})) ----------------------------
        layer_rule = [
          {name = "blur-gtk"; match.namespace = "gtk-layer-shell"; blur = true; ignore_alpha = 0.1;}
          {name = "blur-waybar"; match.namespace = "waybar"; blur = true; ignore_alpha = 0.1;}
          {name = "blur-wofi"; match.namespace = "wofi"; blur = true; ignore_alpha = 0.1;}
        ];

        # --- Window Rules (→ hl.window_rule({...})) --------------------------
        window_rule = [
          # Float dialog-like windows automatically
          {name = "float-dialogs"; match.class = "^(?i:file_progress|confirm|dialog|download|notification|error|splash|confirmreset)$"; float = true;}
          {name = "float-file-dialogs"; match.title = "^(Open File|Save File|branchdialog)$"; float = true;}

          # Application-specific float rules
          {name = "float-apps"; match.class = "^(Wofi|dunst|Viewnior|feh|blueman-manager)$"; float = true;}
          {name = "float-audio"; match.class = "^(pavucontrol(-qt)?|org.gnome.FileRoller)$"; float = true;}
          {name = "no-anim-wofi"; match.class = "^(Wofi)$"; no_anim = true;}

          # Volume control sizing and positioning
          {name = "volume-control"; match.title = "^(Volume Control)$"; float = true; size = "800 600"; move = "75 44%";}

          # Picture-in-Picture: float, pin, resize
          {name = "pip"; match.title = "^(Picture-in-Picture)$"; float = true; pin = true; size = "480 270";}

          # wlogout fullscreen
          {name = "wlogout"; match.title = "^(wlogout)$"; fullscreen = true; float = true;}

          # Force full opacity on browsers (blur looks bad through text)
          {name = "browser-opacity"; match.class = "^(firefox|chromium-browser)$"; opacity = 1.0;}
        ] ++ workspaceWindowRules;
      };

      # Raw Lua appended after the generated settings block.
      # Contains env vars, bezier curves, startup commands, and all keybindings
      # using the 0.55.2 hl.bind(key, hl.dsp.*) API.
      extraConfig = ''
        -- Hyper chord: matches keyd's hyper:C-A-M layer output (physical Ctrl key).
        -- On macOS Karabiner emits the same Ctrl+Alt+Cmd chord — Aerospace binds
        -- to `ctrl-alt-cmd`, keeping WM shortcuts identical across platforms.
        -- NB: Hyprland's key parser requires `+` between each modifier.
        local mainMod = "CTRL + ALT + SUPER"

        -- Environment variables (two-arg form required in 0.55.2)
        hl.env("XCURSOR_SIZE", "32")
        hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
        hl.env("XDG_SESSION_DESKTOP", "Hyprland")
        hl.env("XDG_SESSION_TYPE", "wayland")
        hl.env("GTK_THEME", "${theme.gtkThemeName}")
        hl.env("TERMINAL", "ghostty")

        -- Startup (exec-once equivalent; systemd session setup handled by systemd.enable)
        hl.on("hyprland.start", function()
          hl.exec_cmd("swww-daemon && sleep 0.5 && $HOME/.local/bin/wallpaper-random")
          hl.exec_cmd("waybar")
          hl.exec_cmd("blueman-applet")
        end)

        -- Core launcher bindings
        hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"))
        hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd("wofi --show drun"))
        hl.bind(mainMod .. " + Space",  hl.dsp.window.float({action = "toggle"}))
        hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen())
        hl.bind(mainMod .. " + W",      hl.dsp.window.close())
        hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("thunar"))
        hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("hyprlock"))
        hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("wlogout -p layer-shell"))

        -- Workspace cycling (arrows — matches macOS Ctrl+arrows convention)
        hl.bind(mainMod .. " + left",  hl.dsp.focus({workspace = "r-1"}))
        hl.bind(mainMod .. " + right", hl.dsp.focus({workspace = "r+1"}))

        -- Window focus (comma/period for horizontal, arrows for vertical)
        hl.bind(mainMod .. " + comma",  hl.dsp.focus({direction = "left"}))
        hl.bind(mainMod .. " + period", hl.dsp.focus({direction = "right"}))
        hl.bind(mainMod .. " + up",     hl.dsp.focus({direction = "up"}))
        hl.bind(mainMod .. " + down",   hl.dsp.focus({direction = "down"}))

        -- Dropdown terminal (CapsLock+` = Ctrl+grave via keyd)
        hl.bind("CTRL + grave", hl.dsp.exec_cmd("$HOME/.local/bin/dropdown-terminal"))

        -- Wallpaper controls
        hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("$HOME/.local/bin/wallpaper-random"))

        -- CUA / application bindings
        hl.bind("ALT + F4", hl.dsp.window.close())

        -- Move window to adjacent workspace (shift+arrows)
        hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({workspace = "r-1"}))
        hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({workspace = "r+1"}))
        hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({direction = "up"}))
        hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({direction = "down"}))

        -- Move window within workspace (shift+comma/period)
        hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.window.move({direction = "left"}))
        hl.bind(mainMod .. " + SHIFT + period", hl.dsp.window.move({direction = "right"}))

        -- Numbered workspaces (1-9, then 0→10)
        for i = 1, 9 do
          hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({workspace = i}))
          hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({workspace = i}))
        end
        hl.bind(mainMod .. " + 0",         hl.dsp.focus({workspace = 10}))
        hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({workspace = 10}))

        -- Screenshots
        hl.bind(mainMod .. " + SHIFT + S",     hl.dsp.exec_cmd("bash -lc 'grim -g \"$(slurp)\" \"$HOME/Pictures/Screenshots/$(date +%Y-%m-%d-%H%M%S).png\"'"))
        hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("bash -lc 'grim \"$HOME/Pictures/Screenshots/$(date +%Y-%m-%d-%H%M%S).png\"'"))
        hl.bind(mainMod .. " + ALT + S",       hl.dsp.exec_cmd("$HOME/.local/bin/screenshot-area-annotate"))
        hl.bind(mainMod .. " + ALT + O",       hl.dsp.exec_cmd("$HOME/.local/bin/ocr-screenshot"))
        hl.bind(mainMod .. " + V",             hl.dsp.exec_cmd("$HOME/.local/bin/cliphist-wofi"))
        hl.bind(mainMod .. " + SHIFT + C",     hl.dsp.exec_cmd("hyprpicker -a"))

        -- Workspace cycling with mouse wheel
        hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({workspace = "e-1"}))
        hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({workspace = "e+1"}))

        -- Mouse window manipulation
        hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   {mouse = true})
        hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), {mouse = true})

        -- Keyboard resize submap (SUPER+R enters, arrows resize, Escape exits)
        hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
        hl.define_submap("resize", "reset", function()
          hl.bind("right", hl.dsp.window.resize({x = 10,  y = 0,   relative = true}), {repeating = true})
          hl.bind("left",  hl.dsp.window.resize({x = -10, y = 0,   relative = true}), {repeating = true})
          hl.bind("up",    hl.dsp.window.resize({x = 0,   y = -10, relative = true}), {repeating = true})
          hl.bind("down",  hl.dsp.window.resize({x = 0,   y = 10,  relative = true}), {repeating = true})
          hl.bind("Escape", hl.dsp.submap("reset"))
        end)

        -- Media and function keys (locked = active on lock screen, repeating = held key repeats)
        hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {locked = true, repeating = true})
        hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      {locked = true, repeating = true})
        hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     {locked = true})
        hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   {locked = true})
        hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  {locked = true, repeating = true})
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  {locked = true, repeating = true})
        hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                           {locked = true})
        hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                 {locked = true})
        hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                             {locked = true})
      '';
    };
  };
}
