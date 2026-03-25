# Design: Comprehensive `ujust update` Command

## Problem

Currently `ujust update` only updates nix flake inputs, commits flake.lock, and switches. On Universal Blue distros, `ujust update` is a one-stop command that updates everything on the machine. We want the same UX pattern for this nixcfg setup.

## Scope

Rewrite the `update` recipe in `home/features/cli/ujust.just` to run all update tasks sequentially with section headers and a pass/fail summary.

## Update Sections (in order)

### 1. System (nix)

The nix section inlines its own logic (does NOT delegate to `nixcfg-update-switch`) because the comprehensive update has different dirty-repo semantics: it warns and continues with other sections rather than aborting entirely.

- Pull nixcfg repo: `git -C "$repo" pull --ff-only`
  - If repo has uncommitted changes: skip pull, warn, continue to flake update
  - If pull fails for any reason (network, diverged history, no upstream): warn, continue to flake update
- Update flake inputs: `just --justfile "$repo/justfile" --working-directory "$repo" update`
- Commit flake.lock if changed: `git -C "$repo" add flake.lock && git -C "$repo" diff --cached --quiet -- flake.lock || git -C "$repo" commit -m "$MESSAGE" -- flake.lock`
  - Uses `-- flake.lock` to commit only that file, safe even with other staged/unstaged changes
- Switch: `just --justfile "$repo/justfile" --working-directory "$repo" switch`

Note: `nixcfg-update-switch` stays as-is for strict nix-only updates (aborts on dirty repo).

### 2. Homebrew (macOS only)

- Gate: `uname -s` = Darwin AND `command -v brew`
- Run: `brew update && brew upgrade` (no `--greedy`; nix-darwin manages cask updates via `onActivation`)
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

- Loop over `~/src/*/` directories (use bash `nullglob` to handle empty directory)
- Skip entries that are not git repositories (no `.git` directory)
- Run: `git -C "$dir" fetch --all`
- Report fetch failures as warnings, don't abort
- If `~/src` doesn't exist or is empty, skip with "skipped" status

### 6. Summary

- Print a summary table showing each section with its status: OK / WARN / FAIL / SKIPPED
- Use `gum style` for formatting, consistent with `doctor` command

## UX Details

- Section headers via `gum style --bold --foreground 12 "$section_name"`
- Status helpers: `ok()`, `warn()`, `fail()` matching the `doctor` pattern
- No interactive prompts — runs everything automatically
- Individual section failures don't abort the whole update
- Summary at the end shows what happened
- `gum` is a guaranteed dependency (provided by nix home-manager config)

## Status tracking

Use simple bash variables (`status_nix`, `status_brew`, etc.) to accumulate per-section results. Values: "ok", "warn", "fail", "skipped".

## Exit code

Exit 0 if all sections completed (including warnings/skipped). Exit 1 if any section FAILed (switch failed, etc.). This allows scripted use while not treating skips/warnings as errors.

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
