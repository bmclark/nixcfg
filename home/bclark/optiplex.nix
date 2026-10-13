# Home-manager config for bclark on optiplex (DRAFT).
# Desktop feature set mirrors maverick; no laptop-specific bits.
{pkgs, ...}: {
  # Shared base (username, homeDirectory, stateVersion) lives in ./home.nix.
  imports = [
    ../common/default.nix
    ../common/dotfiles
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

  # home.nix (shared base) sets username/homeDirectory/stateVersion.
}
