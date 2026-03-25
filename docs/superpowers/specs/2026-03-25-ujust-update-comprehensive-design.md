# Design: Comprehensive `ujust update` Command

## Problem

Currently `ujust update` only updates nix flake inputs, commits flake.lock, and switches. On Universal Blue distros, `ujust update` is a one-stop command that updates everything on the machine. We want the same UX pattern for this nixcfg setup.

## Scope

Rewrite the `update` recipe in `home/features/cli/ujust.just` to run all update tasks sequentially with section headers and a pass/fail summary.

## Update Sections (in order)

### 1. System (nix)

- Pull nixcfg repo: `git -C "$repo" pull --ff-only`
  - Fail gracefully if remote is unreachable (warn, continue)
  - If repo has uncommitted changes: skip pull, warn, but still proceed with flake update
- Update flake inputs: delegate to `just --justfile "$repo/justfile" update`
- Commit flake.lock if changed: `git add flake.lock && git commit -m "$MESSAGE"`
- Switch: delegate to `just --justfile "$repo/justfile" switch`

Note: this replaces the current `update` recipe behavior. The `nixcfg-update-switch` recipe stays as-is for independent use.

### 2. Homebrew (macOS only)

- Gate: `uname -s` = Darwin AND `command -v brew`
- Run: `brew update && brew upgrade`
- Skip with "skipped" status if not macOS or brew not found

### 3. Flatpak (Linux only)

- Gate: `uname -s` = Linux AND `command -v flatpak`
- Run: `flatpak update -y`
- Skip with "skipped" status if not Linux or flatpak not found

### 4. Firmware (Linux only)

- Gate: `uname -s` = Linux AND `command -v fwupdmgr`
- Run: `fwupdmgr refresh && fwupdmgr get-updates` (report only, no auto-install)
- Skip with "skipped" status if not Linux or fwupdmgr not found
- Non-zero exit from `get-updates` when no updates available is not an error

### 5. Git repos (`~/src`)

- Loop over `~/src/*/` directories
- Skip entries that are not git repositories (no `.git` directory)
- Run: `git -C "$dir" fetch --all`
- Report fetch failures as warnings, don't abort
- If `~/src` doesn't exist, skip with "skipped" status

### 6. Summary

- Print a summary table showing each section with its status: OK / WARN / FAIL / SKIPPED
- Use `gum style` for formatting, consistent with `doctor` command

## UX Details

- Section headers via `gum style --bold --foreground 12 "$section_name"`
- Status helpers: `ok()`, `warn()`, `fail()` matching the `doctor` pattern
- No interactive prompts — runs everything automatically
- Individual section failures don't abort the whole update
- Summary at the end shows what happened

## Recipe structure

- `update MESSAGE="chore: update flake inputs"` — the comprehensive command (rewritten)
- `nixcfg-update-switch` — unchanged, available for nix-only updates
- `nixcfg-update` — unchanged, available for flake-only updates

## Files changed

- `home/features/cli/ujust.just` — rewrite `update` recipe

## Out of scope

- Automatic firmware installation (too risky for unattended operation)
- Parallel execution of sections
- Interactive per-section confirmation
