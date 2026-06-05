# Helper commands for managing this flake across NixOS, nix-darwin, and home-manager.
# Requires `just` (install with `nix-shell -p just` or add to your system packages).
# Recipes are grouped by platform and workflow for quick navigation.
#
# Use explicit `path:` flake refs so working-tree renames and untracked files
# are visible during local rebuilds and checks.

# --------------------------------------------------
# Default
default:
    @just --list

# --------------------------------------------------
# NixOS Commands
_require-nixos-rebuild:
    @command -v nixos-rebuild >/dev/null 2>&1 || { echo "nixos-rebuild is required for this recipe"; exit 1; }

nixos-switch-host SYSTEM:
    @just _require-nixos-rebuild
    @sudo nixos-rebuild switch --flake path:$(pwd)#{{SYSTEM}} --impure

nixos-switch:
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    if [ "$HOST" = "nixos" ]; then HOST=maverick; fi ; \
    just nixos-switch-host $HOST

nixos-test:
    @just _require-nixos-rebuild
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    if [ "$HOST" = "nixos" ]; then HOST=maverick; fi ; \
    sudo nixos-rebuild test --flake path:$(pwd)#$HOST --impure

nixos-boot:
    @just _require-nixos-rebuild
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    if [ "$HOST" = "nixos" ]; then HOST=maverick; fi ; \
    sudo nixos-rebuild boot --flake path:$(pwd)#$HOST --impure

nixos-build SYSTEM:
    @just _require-nixos-rebuild
    @nixos-rebuild build --flake path:$(pwd)#{{SYSTEM}} --impure

build-current:
    @if [ "$(uname -s)" = "Darwin" ]; then \
        just darwin-build; \
    else \
        HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
        if [ "$HOST" = "nixos" ]; then HOST=maverick; fi ; \
        just nixos-build $HOST; \
    fi

deploy-to HOST SYSTEM:
    @just _require-nixos-rebuild
    @nixos-rebuild switch --flake path:$(pwd)#{{SYSTEM}} --target-host {{HOST}} --use-remote-sudo

deploy SYSTEM:
    @just deploy-to {{SYSTEM}} {{SYSTEM}}

# --------------------------------------------------
# Darwin Commands
_require-darwin-rebuild:
    @command -v darwin-rebuild >/dev/null 2>&1 || { echo "darwin-rebuild is required for this recipe"; exit 1; }

darwin-switch-host SYSTEM:
    @just _require-darwin-rebuild
    @sudo darwin-rebuild switch --flake path:$(pwd)#{{SYSTEM}} --impure
    @just _reload-aerospace

darwin-switch:
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    just darwin-switch-host $HOST

_reload-aerospace:
    @current_user="$(id -un)"; \
    if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then \
        user="$SUDO_USER"; \
    else \
        user="$current_user"; \
    fi; \
    if pgrep -qx -u "$user" AeroSpace 2>/dev/null; then \
        aero="$(command -v aerospace)" || { echo "aerospace CLI not found"; exit 1; }; \
        if [ "$current_user" = "$user" ]; then \
            "$aero" reload-config && echo "AeroSpace config reloaded"; \
        else \
            sudo -H -u "$user" "$aero" reload-config && echo "AeroSpace config reloaded"; \
        fi; \
    else \
        echo "AeroSpace is not running for $user — start it with: open -a AeroSpace"; \
    fi

darwin-test:
    @just _require-darwin-rebuild
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    darwin-rebuild check --flake path:$(pwd)#$HOST --impure

darwin-build:
    @just _require-darwin-rebuild
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    darwin-rebuild build --flake path:$(pwd)#$HOST --impure

# --------------------------------------------------
# Home Manager Commands
# Useful for quick user-space tweaks without a full system rebuild.
_require-home-manager:
    @command -v home-manager >/dev/null 2>&1 || { echo "home-manager is required for this recipe"; exit 1; }

home-switch-host HOST:
    @just _require-home-manager
    @NIXPKGS_ALLOW_UNFREE=1 home-manager switch --impure --flake path:$(pwd)#bclark@{{HOST}}

home-switch:
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    if [ "$HOST" = "nixos" ]; then HOST=maverick; fi ; \
    just home-switch-host $HOST

home-build-host HOST:
    @just _require-home-manager
    @NIXPKGS_ALLOW_UNFREE=1 home-manager build --impure --flake path:$(pwd)#bclark@{{HOST}}

home-build:
    @HOST=${HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')} ; \
    if [ "$HOST" = "nixos" ]; then HOST=maverick; fi ; \
    just home-build-host $HOST

# --------------------------------------------------
# Cross-Platform Commands
switch:
    @if [ "$(uname -s)" = "Darwin" ]; then \
        just darwin-switch; \
    else \
        just nixos-switch; \
    fi

test:
    @if [ "$(uname -s)" = "Darwin" ]; then \
        just darwin-test; \
    else \
        just nixos-test; \
    fi

build-all:
    @just nixos-build maverick
    @if command -v darwin-rebuild >/dev/null 2>&1; then \
        just darwin-build; \
    else \
        echo "Skipping darwin-build: darwin-rebuild is not available on this host"; \
    fi

# --------------------------------------------------
# Update Workflow
update:
    @nix flake update --flake path:$(pwd)

update-input INPUT:
    @nix flake lock --update-input {{INPUT}} --flake path:$(pwd)

# Updates flake, rebuilds both systems, and switches current machine; cross-host switching requires remote access setup.
update-all: update
    @just build-all
    @just switch

# --------------------------------------------------
# Maintenance
gc:
    @nix-collect-garbage --delete-older-than 7d

gc-old:
    @nix-collect-garbage --delete-older-than 30d

gc-all:
    @sudo nix-collect-garbage -d

optimize:
    @nix-store --optimize

clean:
    @just gc
    @just optimize

user-services:
    @systemctl --user --failed

user-status:
    @systemctl --user status --no-pager

git-signing-status:
    @echo "git user.signingkey: $$(git config --get user.signingkey || echo unset)"
    @echo "git commit.gpgsign: $$(git config --get commit.gpgsign || echo unset)"
    @echo "gpg secret keys:"
    @gpg --list-secret-keys --keyid-format LONG

ocr-shot:
    @$HOME/.local/bin/ocr-screenshot

ocr-image FILE:
    @$HOME/.local/bin/ocr-image {{FILE}}

ocr-pdf FILE PAGE="1":
    @$HOME/.local/bin/ocr-pdf {{FILE}} {{PAGE}}

# --------------------------------------------------
# Flake Utilities
check:
    @nix flake check path:$(pwd)

show:
    @nix flake show path:$(pwd)

show-json:
    @nix flake show --json path:$(pwd)

check-trace:
    @nix flake check --show-trace path:$(pwd)

# --------------------------------------------------
# Git Workflow
commit MESSAGE:
    @git add .
    @git commit -m "{{MESSAGE}}"

push:
    @git push

update-and-commit MESSAGE: update
    @just commit "{{MESSAGE}}"

deploy-update-commit SYSTEM MESSAGE: (deploy SYSTEM) update
    @just commit "{{MESSAGE}}"
    @just push

# --------------------------------------------------
# Theme Switching
# Rebuild with a different theme. Available: dracula (default), tokyo-night, synthwave84
# Example: just theme tokyo-night
theme THEME="dracula":
    @NIXCFG_THEME={{THEME}} just switch

# --------------------------------------------------
# Development Environments
dev-shell:
    @nix develop path:$(pwd)

dev: dev-shell
