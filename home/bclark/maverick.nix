# NixOS laptop (maverick) -- x86_64-linux with Hyprland.
{pkgs, ...}: {
  imports = [
    ../common/default.nix
    ./dotfiles
    ../features/cli
    ../features/desktop
    ../features/development
    ../features/editors
    ./home.nix
  ];

  features = {
    cli = {
      zsh.enable = true;
      fzf.enable = true;
      ghostty.enable = true;
      tmux.enable = true;
      atuin.enable = true;
    };
    desktop = {
      fonts.enable = true;
      hyprland.enable = true;
      wayland.enable = true;
      firefox.enable = true;
      chromium.enable = true;
      remoteDesktop.enable = true;
    };
    development = {
      git.enable = true;
      vscode.enable = true;
    };
    editors = {
      emacs.enable = true;
    };
  };

  # --- Weekly flake update timer --------------------------------------------
  # Runs `nix flake update` every Sunday at 09:00. Review changes with `git diff flake.lock`.
  systemd.user.services.flake-update = {
    Unit.Description = "Update nixcfg flake inputs";
    Service = {
      Type = "oneshot";
      WorkingDirectory = "%h/nixcfg";
      ExecStart = "${pkgs.nix}/bin/nix flake update";
    };
  };
  systemd.user.timers.flake-update = {
    Unit.Description = "Weekly nixcfg flake update";
    Timer = {
      OnCalendar = "Sun 09:00";
      Persistent = true; # Run missed timers after boot
    };
    Install.WantedBy = ["timers.target"];
  };

  wayland.windowManager.hyprland = {
    settings = {
      device = [
        {name = "keyboard"; kb_layout = "us";}
        {name = "mouse"; sensitivity = -0.5;}
      ];
      # hl.monitor({output, mode, position, scale}) — Lua API 0.55.2
      monitor = [
        {output = "eDP-1"; mode = "1920x1080@60"; position = "0x0"; scale = 1;}
      ];
      # hl.workspace_rule({workspace, monitor?, default?, on_created_empty?, gaps_out?}) — Lua API 0.55.2
      workspace_rule = [
        {workspace = "1"; monitor = "eDP-1"; default = true;}
        {workspace = "2"; monitor = "eDP-1";}
        {workspace = "3"; monitor = "eDP-1";}
        {workspace = "4"; monitor = "eDP-1";}
        {workspace = "5"; monitor = "eDP-1";}
        {workspace = "6"; monitor = "eDP-1";}
        {workspace = "7"; monitor = "eDP-1";}
        {workspace = "special:terminal"; on_created_empty = "ghostty"; gaps_out = 0;}
      ];
    };
  };
}
