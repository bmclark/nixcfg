{
  description = ''
    NixOS and nix-darwin configuration for managing multiple systems.

    Managed systems:
    - maverick: NixOS laptop with Hyprland
    - iceman: macOS Mac Mini with nix-darwin

    Features:
    - Modular feature-based architecture
    - Switchable theme system (Dracula, Tokyo Night, SynthWave '84)
    - Cross-platform home-manager integration
    - Consistent keyboard shortcuts (Ctrl for apps, Super for WM)

    Original configuration structure inspired by:
    - https://code.m3ta.dev/m3tam3re/nixcfg
    - https://github.com/Misterio77/nix-config
  '';

  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-nixos.url = "github:utensils/mcp-nixos";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
  };

  outputs = {
    self,
    agenix,
    home-manager,
    mcp-nixos,
    nix-homebrew,
    nix-vscode-extensions,
    nur,
    nixpkgs,
    nixpkgs-stable,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # Switchable theme: set NIXCFG_THEME env var to switch (default: dracula).
    # Available: "dracula", "tokyo-night", "synthwave84"
    # Usage: NIXCFG_THEME=tokyo-night just switch
    themeName = let
      env = builtins.getEnv "NIXCFG_THEME";
    in
      if env != ""
      then env
      else "dracula";
    theme = import ./home/themes/${themeName}.nix;

    # NUR provides pkgs.nur.repos.rycee.firefox-addons for declarative
    # Firefox extension packages (see home/features/desktop/firefox.nix).
    sharedOverlays = [nur.overlays.default];

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = sharedOverlays;
      };
  in {
    overlays = {
      additions = final: _prev: {};
      modifications = final: prev: {};
      mcp-nixos = mcp-nixos.overlays.default;
      stable-packages = final: _prev: {};
    };

    homeManagerModules = {};

    homeConfigurations = let
      maverickHome = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "x86_64-linux";
        extraSpecialArgs = {inherit inputs outputs theme themeName nix-vscode-extensions;};
        modules = [./home/bclark/maverick.nix];
      };

      icemanHome = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "aarch64-darwin";
        extraSpecialArgs = {inherit inputs outputs theme themeName nix-vscode-extensions;};
        modules = [./home/bclark/iceman.nix];
      };
    in {
      "bclark@maverick" = maverickHome;
      "bclark@iceman" = icemanHome;

      # Temporary compatibility aliases for pre-rename hostnames and existing
      # workflows. Remove once both machines have switched cleanly to
      # `maverick` / `iceman` and any shell aliases have been updated.
      "bclark@carbon" = maverickHome;
      "bclark@macmini" = icemanHome;
      "bclark@bryansmacmini" = icemanHome;
    };

    # Project templates: nix flake init -t .#python (etc.)
    templates = {
      python = {
        description = "Python development environment with uv + ruff";
        path = ./templates/python;
      };
      typescript = {
        description = "TypeScript/Node.js development environment with pnpm";
        path = ./templates/typescript;
      };
      rust = {
        description = "Rust development environment with cargo + clippy";
        path = ./templates/rust;
      };
      go = {
        description = "Go development environment with gopls + golangci-lint";
        path = ./templates/go;
      };
      terraform = {
        description = "Terraform/OpenTofu IaC development environment";
        path = ./templates/terraform;
      };
    };

    nixosConfigurations = let
      maverickSystem = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs theme themeName;};
        modules = [
          ./hosts/maverick
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {nixpkgs.overlays = sharedOverlays;}
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = {inherit inputs outputs theme themeName nix-vscode-extensions;};
              users.bclark = import ./home/bclark/maverick.nix;
            };
          }
        ];
      };
    in {
      maverick = maverickSystem;
      # Temporary compatibility aliases for the old hostname and factory
      # default hostname. Remove after the laptop is consistently rebuilding
      # as `maverick`.
      carbon = maverickSystem;
      nixos = maverickSystem;
    };

    darwinConfigurations = let
      icemanSystem = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {inherit inputs outputs theme themeName;};
        modules = [
          ./darwin/iceman
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {nixpkgs.overlays = sharedOverlays;}
          {
            nix-homebrew = {
              enable = true;
              autoMigrate = true;
              user = "bclark";
            };
          }
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = {inherit inputs outputs theme themeName nix-vscode-extensions;};
              users.bclark = import ./home/bclark/iceman.nix;
            };
          }
        ];
      };
    in {
      iceman = icemanSystem;
      # Temporary compatibility aliases for the old hostnames. Remove after
      # the Mac is consistently rebuilding as `iceman`.
      macmini = icemanSystem;
      bryansmacmini = icemanSystem;
    };
  };
}
