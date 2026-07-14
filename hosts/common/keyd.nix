# keyd: system-level key remapping daemon. Implements ADR-003.
#
# Three separated modifier namespaces:
#   - CapsLock → Ctrl                (Emacs / shell / logical Ctrl)
#   - Physical Ctrl → Hyper (C-A-M)  (Hyprland WM; matches macOS Karabiner)
#   - Physical Super/Windows → super_cua layer → Ctrl+letter (CUA copy/paste)
#
# The `hyper:C-A-M` layer has no explicit bindings — its `:C-A-M` suffix tells
# keyd to emit Ctrl+Alt+Meta chord for any key pressed while the layer is
# active. Hyprland binds to `CTRL ALT SUPER` to receive this.
#
# Note: keyd cannot exclude per-app (it operates below the compositor).
# For Emacs on Linux, CUA mode handles the translated Ctrl keys contextually.
{...}: {
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        main = {
          capslock = "leftcontrol";
          leftcontrol = "layer(hyper)";
          rightcontrol = "layer(hyper)";
          leftmeta = "layer(super_cua)";
          rightmeta = "layer(super_cua)";
        };
        # Hyper layer: no explicit bindings. The `:C-A-M` suffix on the layer
        # name causes keyd to emit Ctrl+Alt+Meta modifiers for every key
        # pressed while the layer is active, forming the Hyper chord.
        "hyper:C-A-M" = {};
        # Super (physical Windows/Cmd key) → Ctrl for common CUA shortcuts.
        # Makes Super+C/V/X/Z/S/A/F/W/T/N/Q match macOS muscle memory.
        "super_cua" = {
          c = "C-c";       # copy
          v = "C-v";       # paste
          x = "C-x";       # cut
          z = "C-z";       # undo
          # redo: shift+z not valid in keyd 2.6.0 layer syntax
          a = "C-a";       # select all
          s = "C-s";       # save
          f = "C-f";       # find
          w = "C-w";       # close tab/window
          t = "C-t";       # new tab
          n = "C-n";       # new window
          q = "C-q";       # quit
          l = "C-l";       # address bar / go-to-line
          r = "C-r";       # reload / replace
          p = "C-p";       # print / quick-open
        };
      };
    };
  };
}
