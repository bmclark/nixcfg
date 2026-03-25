# Homebrew on macOS: declarative management of casks, formulae, and Mac App Store apps.
# Aerospace and Karabiner-Elements are managed by nix-darwin services, not Homebrew.
# Ghostty has no nixpkgs macOS build; config is shared via home/features/cli/ghostty.nix.
# onActivation.cleanup = "zap" removes anything not declared here -- add before installing.
{...}: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";

    brews = [
      "mas" # Mac App Store CLI (used by masApps below)
      "tdd-guard" # TDD file watcher (not in nixpkgs)
    ];

    casks = [
      "audacity" # Audio editor
      "alt-tab" # Alt+Tab-style app switcher on macOS
      "chatgpt" # OpenAI ChatGPT desktop app
      "claude" # Anthropic Claude desktop app
      "codex" # OpenAI Codex desktop app
      "ghostty" # Terminal emulator (no nixpkgs macOS build)
      "google-chrome" # Chromium replacement on macOS (nixpkgs chromium unavailable on aarch64-darwin)
      # karabiner-elements now managed by services.karabiner-elements in nix-darwin
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
