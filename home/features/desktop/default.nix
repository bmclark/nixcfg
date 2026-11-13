# Desktop modules: window manager, browsers, fonts, input remapping, and remote access helpers.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.desktop.remoteDesktop;
  remoteDesktopScript = ''
    default_target=${escapeShellArg cfg.defaultHost}
    target="''${1:-$default_target}"
    exec remmina -c "vnc://$target"
  '';
  icemanRemote = pkgs.writeShellApplication {
    name = "iceman-remote";
    runtimeInputs = [pkgs.remmina];
    text = remoteDesktopScript;
  };
  # Temporary compatibility wrapper. Remove after `iceman-remote` is the only
  # helper referenced in shell history, docs, and personal scripts.
  macminiRemoteCompat = pkgs.writeShellApplication {
    name = "macmini-remote";
    runtimeInputs = [pkgs.remmina];
    text = remoteDesktopScript;
  };
in {
  imports = [
    ./fonts.nix
    ./hyprland.nix
    ./wayland.nix
    ./firefox.nix
    ./chromium.nix
    ./karabiner.nix
    ./aerospace.nix
  ];

  options.features.desktop.remoteDesktop = {
    enable = mkEnableOption "remote desktop client tools";

    defaultHost = mkOption {
      type = types.str;
      default = "iceman";
      example = "100.101.102.103";
      description = ''
        Default host or Tailscale IP for the `iceman-remote` helper.
        The default assumes Tailscale MagicDNS resolves `iceman`.
      '';
    };
  };

  config = mkMerge [
    {
      home.packages = with pkgs; [tree];
    }
    (mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        audacity
        # FIXME: bitwarden-desktop disabled — electron-39 fails to build
        # upstream (nixpkgs patch drift in chromium/angle). Re-enable after
        # `nix flake update`.
        # bitwarden-desktop
        spotify
        telegram-desktop
      ];
    })
    (mkIf (cfg.enable && pkgs.stdenv.isLinux) {
      home.packages = [
        pkgs.remmina
        icemanRemote
        macminiRemoteCompat
      ];
    })
  ];
}
