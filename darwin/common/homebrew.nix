# Homebrew on macOS: declarative management of casks, formulae, and Mac App Store apps.
# Aerospace is managed by nix-darwin services, not Homebrew.
# Karabiner-Elements via Homebrew until nix-darwin#1679 lands (key config still via home-manager).
# Ghostty has no nixpkgs macOS build; config is shared via home/features/cli/ghostty.nix.
# cmux wraps Ghostty's renderer; reads ~/.config/ghostty/config + its own ~/.config/cmux/settings.json.
# onActivation.cleanup = "zap" removes anything not declared here -- add before installing.
{...}: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";

    taps = [
      "steipete/tap" # remindctl: Apple Reminders CLI, not in nixpkgs
    ];

    brews = [
      "mas" # Mac App Store CLI (used by masApps below)
      "remindctl" # Apple Reminders CLI for org/Apple execution bridge
      "tdd-guard" # TDD file watcher (not in nixpkgs)
    ];

    casks = [
      "audacity" # Audio editor
      "alt-tab" # Alt+Tab-style app switcher on macOS
      "chatgpt" # OpenAI ChatGPT desktop app
      "claude" # Anthropic Claude desktop app
      "codex" # OpenAI Codex desktop app
      "cmux" # Terminal workspace manager (wraps Ghostty renderer)
      "ghostty" # Terminal emulator (no nixpkgs macOS build)
      "google-chrome" # Chromium replacement on macOS (nixpkgs chromium unavailable on aarch64-darwin)
      "karabiner-elements" # Keyboard remapping (nix-darwin module broken with v15+, see nix-darwin#1679)
      "logitech-g-hub" # Logitech peripheral management
      "raycast" # Launcher / productivity tool
      "spotify" # Music streaming
      "tailscale-app" # VPN mesh network (menu bar app)
    ];

    masApps = {
      "Bitwarden" = 1352778147;
      "Capital One Shopping" = 1477110326;
      "GarageBand" = 682658836;
      "iMovie" = 408981434;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "uBlock Origin Lite" = 6745342698;
      "Xcode" = 497799835;
    };
  };
}
