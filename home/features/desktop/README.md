# Desktop Features

Window manager, Wayland desktop services, browsers, fonts, and keyboard remapping for the graphical environment.

## Start Here

On the NixOS laptop (`maverick`), the desktop is built around **Hyprland**:
- Hyprland manages windows and workspaces.
- Waybar shows status and workspace state.
- Wofi launches apps.
- Dunst handles notifications.
- Hyprlock locks the screen.
- Ghostty is the main terminal app.

On the macOS host (`iceman`), the desktop is built around **Aerospace** plus **Karabiner**:
- Aerospace manages windows and workspaces.
- Karabiner maps `CapsLock -> Ctrl` and physical `Ctrl -> Hyper`.
- Raycast is the app launcher.
- Ghostty is the main terminal app.

## What To Use When

| Tool | Use it for | Prefer it over |
|------|------------|----------------|
| Hyprland / Aerospace | Moving windows, switching workspaces, layout control | Using app-level tabs or panes to simulate OS-level workspace management |
| Wofi / Raycast | Launching apps quickly | Digging through menus |
| Waybar | Seeing workspace state, media, battery, network, bluetooth, audio | Opening multiple settings panels just to check status |
| Hyprlock | Locking the session | Logging out when you only need to step away |
| Firefox | Primary browser with stronger privacy defaults | Chromium for normal daily browsing |
| Chromium / Google Chrome | Compatibility fallback | Firefox when a site is broken or requires Chromium behavior |
| Karabiner | macOS keyboard remapping for the shared Ctrl / Hyper layout | Per-app remapping by hand |
| Remmina | Remote desktop sessions such as the Mac Screen Sharing setup | Ad hoc VNC command lines when you want saved profiles or a GUI |

## Desktop Movement And Navigation

In these docs, `Hyper` means the physical `Ctrl` key. Logical `Ctrl` lives on `CapsLock`.
The shortcut tables below lead with the physical keys you actually press.

### Shared Hyper layer

These bindings exist on both hosts:

| Physical key | Action |
|-----|--------|
| `Ctrl+Return` | Open a new terminal |
| `Ctrl+D` | Open the app launcher |
| `Ctrl+Space` | Toggle floating for the current window |
| `Ctrl+F` | Toggle fullscreen |
| `Ctrl+W` | Close the active window |
| `Ctrl+1` .. `Ctrl+0` | Switch to workspace 1..10 |
| `Ctrl+Shift+1` .. `Ctrl+Shift+0` | Move current window to workspace 1..10 |
| `Ctrl+Left` / `Right` / `Up` / `Down` | Focus window left / right / up / down |
| `Ctrl+Shift+Left` / `Right` / `Up` / `Down` | Move window left / right / up / down |

### Linux-specific Hyprland bindings

These are the extra bindings provided on `maverick`:

| Physical key | Action |
|-----|--------|
| `Ctrl+E` | Open Thunar |
| `Ctrl+L` | Lock screen |
| `Ctrl+Escape` | Open logout/power menu |
| `Ctrl+\`` | Toggle the dropdown terminal |
| `Ctrl+,` / `Ctrl+.` | Previous / next workspace |
| `Alt+Tab` / `Alt+Shift+Tab` | Cycle windows forward / backward |
| `Alt+F4` | Close active window |
| `Ctrl+Shift+S` | Area screenshot |
| `Ctrl+Shift+Print` | Full screenshot |
| `Ctrl+Alt+S` | Area screenshot and annotate in Swappy |
| `Ctrl+Alt+O` | OCR selected screen region to clipboard |
| `Ctrl+V` | Clipboard history picker |
| `Ctrl+Shift+C` | Pick a screen color to the clipboard |

### macOS-specific Aerospace bindings

These are the extra bindings or behaviors on `iceman`:

| Shortcut / command | Action |
|-----|--------|
| `Ctrl+\`` | Toggle scratch workspace `S`, creating a Ghostty there on first use |
| `Ctrl+,` / `Ctrl+.` | Previous / next workspace |
| `Ctrl+E` | Open Finder |
| `Ctrl+L` | Lock screen |
| `Alt+Tab` | AltTab app switching |
| `Cmd+Tab` | Native macOS app switching still available |
| `drs` | Rebuild nix-darwin |
| `drt` | Check nix-darwin config without switching |

Hyprland mouse actions:

| Physical key | Action |
|-----|--------|
| `Ctrl+Left click drag` | Move window |
| `Ctrl+Right click drag` | Resize window |
| `Ctrl+mouse wheel` | Cycle workspaces |

Hyprland touchpad:

| Gesture | Action |
|---------|--------|
| Three-finger horizontal swipe | Change workspace |

### Workspaces and automatic placement

Some apps are placed on fixed workspaces on both hosts:

| Workspace | Purpose | macOS apps | Linux apps |
|-----------|---------|------------|------------|
| `1` | Admin | Mail, Notes, Calendar, Bitwarden | thunderbird, notes, calendar, Bitwarden |
| `2` | Browser | Safari, Google Chrome | firefox, chromium |
| `3` | AI / chat | Claude, ChatGPT, Codex | Claude, ChatGPT |
| `4` | Editor | Emacs, Code, Xcode | Emacs, Code |
| `5` | Terminal | Ghostty | Ghostty |
| `6` | Media | Spotify, Audacity, GarageBand, iMovie | Spotify, Audacity |

That means a good default workflow is:
- `Ctrl+4` for editing/coding
- `Ctrl+2` for browser work
- `Ctrl+5` for terminal work
- use later workspaces for project-specific terminals, chat, or misc apps

### Scratch access

On `maverick`, `Ctrl+\`` opens a terminal on a special hidden workspace that drops down from the top of the screen.

Use it for:
- quick commands
- short notes
- one-off git or system checks

Do not treat it as your main long-lived work area; that is better handled by a normal Ghostty window with tmux inside.

On `iceman`, `Ctrl+\`` toggles into and back out of workspace `S`. On first use it creates a Ghostty there automatically, then reuses that scratch terminal afterward.

## Browsers

### Firefox

Firefox is the primary browser, configured as declaratively as home-manager allows
(`home/features/desktop/firefox.nix`).

| Profile | Launch | Use for |
|---------|--------|---------|
| `default` | `firefox` | Day-to-day browsing with the strongest privacy defaults |
| `relaxed` | `firefox -P relaxed` | Sites that break under hardened settings |

**Extensions** are installed as pinned Nix packages from NUR
(`pkgs.nur.repos.rycee.firefox-addons`), not via enterprise-policy `.xpi` downloads —
this means the exact extension build comes from the Nix store and doesn't require a
network fetch from addons.mozilla.org on first launch. `ExtensionSettings."*".installation_mode
= "blocked"` still blocks ad-hoc manual installs from `about:addons`.

- Shared (both profiles): Bitwarden, uBlock Origin, Privacy Badger, Dracula theme,
  Dark Reader, xBrowserSync, Multi-Account Containers, Facebook Container, Tampermonkey,
  Temporary Containers, SponsorBlock, Consent-O-Matic
- Hardened-only (`default` profile): LocalCDN, ClearURLs, Cookie AutoDelete,
  CanvasBlocker, Skip Redirect — left off `relaxed` since these are the ones most
  likely to break sites (Skip Redirect specifically can interfere with OAuth/login
  redirect chains)

**Tampermonkey / userscripts**: Tampermonkey itself installs declaratively like any
other extension, but the userscripts it runs (e.g. 4chan X) live in Tampermonkey's own
internal storage format, which is undocumented and version-dependent — not safe to
hand-write. One-time manual step after your first rebuild: open the Tampermonkey
dashboard and install 4chan X from `https://www.4chan-x.net/builds/4chan-X.user.js`
(visit the URL directly, or Dashboard → Utilities → Import from URL). Tampermonkey
auto-updates it from there — this isn't something you need to repeat.

To add/remove an extension, edit `sharedExtensionPackages` /
`hardenedOnlyExtensionPackages` in `firefox.nix`. List available NUR Firefox addons with:
```
nix eval --json 'nixpkgs#nur.repos.rycee.firefox-addons' --apply builtins.attrNames
```
(requires the NUR overlay, already wired in via `sharedOverlays` in `flake.nix`).

**Containers** (Multi-Account Containers) are declared per-profile in `firefox.nix`:
Personal, Work, Banking, Shopping, Reddit, 4chan — same set on both profiles so
isolation is consistent regardless of which profile you're in.

**Search**: DuckDuckGo (`ddg`) is the declared default engine on both profiles.

**Toolbar**: compact density, bookmarks bar always visible, and uBlock Origin /
Bitwarden / Multi-Account Containers / Dark Reader pinned to the nav-bar in that
order via `browser.uiCustomization.state`. This pref is somewhat fragile across Firefox
versions — if pinned icons look wrong after a rebuild, right-click the toolbar →
"Customize Toolbar" to fix manually, and make sure Firefox has been fully quit
(not just the window closed) and relaunched since the last rebuild — a running
process won't pick up a new toolbar layout.

**General settings** (both profiles, in `sharedUiSettings`):
- Dracula set as the active browser chrome theme (`extensions.activeThemeID`)
- Restore previous session on startup; Home button and new tabs are blank
  (no Firefox-curated/sponsored content)
- Downloads auto-save to `~/Downloads`, no per-file prompt
- PDFs open in Firefox's built-in viewer
- New tabs (including Ctrl+T, not just links) open next to the current tab;
  Ctrl+Tab cycles most-recently-used instead of visual/position order
- Firefox's built-in password manager is disabled (`PasswordManagerEnabled = false`
  policy) — Bitwarden is the single source of truth for saved logins
- Address/payment-card autofill disabled (Bitwarden handles that data too)
- Cookie consent banners auto-rejected where Firefox can detect them
  (`cookiebanners.service.mode`), including in private browsing
- DRM (Widevine) left at Firefox's default (enabled) so streaming sites keep working
- Hardware acceleration/performance left at Firefox's auto-detected recommended
  settings (no known issue to fix)
- Ctrl+Tab shows preview thumbnails; warns before closing multiple tabs at once
- Global Privacy Control signal enabled (`privacy.globalprivacycontrol.enabled`)
- Vertical tabs intentionally left off (kept the standard horizontal tab strip)

**Hardened-profile-only settings**: referrer trimming
(`network.http.referer.XOriginPolicy`/`XOriginTrimmingPolicy` = 2, arkenfox-style —
cross-origin referrers are stripped to origin-only). Not applied to `relaxed` to
avoid extra site-breakage risk there.

**Site → container assignment is intentionally NOT declared in Nix.** Multi-Account
Containers stores "Always Open This Site In" rules in its own extension storage
(`browser.storage.local`), keyed by hostname, and each record needs an internal
`identityMacAddonUUID` the extension generates itself. More importantly,
home-manager deploys `extensions.settings` as an immutable Nix-store symlink — but
this extension needs to keep *writing* to that same file for its own normal
operation. Declaring it in Nix would freeze the file and permanently break your
ability to add new assignments through the UI afterward, on either profile.

The extension does support real cross-device sync (`browser.storage.sync`, tied to
Firefox Sync/Firefox Account) — but this profile's `DisableFirefoxAccounts` /
`DisableAccounts` policies block that. Decide if that tradeoff is worth it; otherwise
assignments are a one-time manual step per device:

1. Right-click a link (or the tab) → **Open in New Container Tab** → pick the container
2. In that tab, click the container badge in the address bar → **Always Open in
   [Container]**

Repeat per site, per device. Current list: _(fill in as you set these up)_.

**Bookmarks**: not declared yet. `firefox.nix` has a commented scaffold
(`profiles.<name>.bookmarks = { force = true; settings = [...]; }`) ready to fill in;
left inactive since bookmark content is personal and `force = true` on an empty list
would wipe existing bookmarks on the next rebuild.

### Chromium

Chromium is the compatibility browser. Use it when:
- a site needs Chromium-specific behavior
- DRM/video behavior differs
- enterprise tooling is unreliable in Firefox

## Cross-Platform App Parity

Apps now installed on both hosts through Nix or nixpkgs where possible:
- `gemini-cli` via home-manager on both hosts
- Bitwarden desktop on Linux via nixpkgs, Bitwarden on macOS via Mac App Store
- Spotify on Linux via nixpkgs, Spotify on macOS via Homebrew cask
- Audacity on Linux via nixpkgs, Audacity on macOS via Homebrew cask

Still not shared declaratively on `maverick`:
- `tdd-guard` is the remaining Linuxbrew candidate; this repo does not manage Linuxbrew yet
- `Claude` desktop app is macOS-only
- `ChatGPT` desktop app is macOS-only
- macOS-only system tools remain mac-only: Aerospace, Karabiner-Elements, Raycast, Logitech G Hub

## Remote Desktop

`maverick` includes Remmina for remote desktop sessions.

For the macOS Screen Sharing setup in this repo:
- launch Remmina from Wofi for a GUI workflow
- or run `iceman-remote` in a shell
- pass a Tailscale IP if MagicDNS is not resolving: `iceman-remote 100.x.y.z`

The helper defaults to `iceman`, which matches the macOS host name managed in the Darwin config.
Authenticate the Mac to Tailscale from the menu bar app on `iceman`; the Linux side only needs the reachable host name or Tailscale IP.

## Desktop Services

### Waybar

Waybar surfaces workspaces, the active window, media, system stats, bluetooth, network, audio, battery, tray, weather, and clock.

Use it as the desktop dashboard:
- check workspace occupancy before switching
- verify bluetooth/network/audio state quickly
- watch battery and media state without opening extra apps

### Dunst

Dunst provides notifications with history and app-specific rules.

Useful behaviors:
- notification history is available through `dunstctl history-pop`
- left click triggers the default action
- middle click closes all notifications
- right click closes the current notification

### Thunar and removable media

Thunar is the lightweight graphical file browser on `maverick`.

Use it for:
- browsing directories visually
- opening and ejecting USB/thumb drives
- quick archive handling through the archive plugin
- opening a terminal in the selected directory
- copying full file paths from the context menu
- running OCR on selected images or PDFs from the context menu

Removable media is automounted by `udiskie`, so mounted drives should show up in Thunar automatically.

### OCR and document helpers

`maverick` includes a lightweight OCR workflow:
- `ocrshot` or `Ctrl+Alt+O` grabs a screen region, OCRs it, and copies the text
- `ocrimg <file>` OCRs an image and copies the text
- `ocrpdf <file> [page]` OCRs a PDF page and copies the text
- `zathura <file.pdf>` opens PDFs in a keyboard-friendly viewer

### Hyprlock and idle flow

The session follows a staged idle chain:
- screen dims after 5 minutes
- lock engages after 15 minutes
- displays power down after 20 minutes

Use `Ctrl+L` when leaving the machine instead of waiting for idle.

## macOS Notes

Karabiner does not remap `Cmd` any more. The current model is:

- `CapsLock` sends logical `Ctrl`
- physical `Ctrl` sends `Hyper`
- `Cmd` stays native for macOS GUI shortcuts

Practical effect:
- `Cmd+C`, `Cmd+V`, `Cmd+Q`, and `Cmd+Tab` keep their normal macOS behavior
- `Ctrl+Return` launches Ghostty
- `Ctrl+D` launches Raycast
- `Ctrl+E` opens Finder
- `Ctrl+L` locks the screen
- `Ctrl+1..0` and `Ctrl+Shift+1..0` manage Aerospace workspaces
- `Ctrl+,` / `Ctrl+.` cycle the persistent `1..10` workspaces
- Karabiner still needs Accessibility and Input Monitoring permissions after install

See [ADR-003](../../../docs/adr/ADR-003-keyboard-remapping-strategy.md) and [docs/keyboard-layout-strategy.md](../../../docs/keyboard-layout-strategy.md).

## Platform Notes

- **Chromium:** Linux-only (`pkgs.chromium` is not available on aarch64-darwin). On macOS, Google Chrome is installed via Homebrew cask (`darwin/common/homebrew.nix`) as the Chromium replacement.
- **Firefox:** available on both platforms via nixpkgs.

## Design Notes

- Hyprland owns window and workspace movement; tmux and Emacs should not be used as substitutes for desktop-level workspace switching.
- Use Ghostty tabs sparingly and tmux heavily if you want durable terminal workflows.
- The keyboard model is intentionally split: logical `Ctrl` on `CapsLock`, `Hyper` on physical `Ctrl`, native `Cmd` preserved on macOS.
- Browser strategy is Firefox first, Chromium second.

See [ADR-003](../../../docs/adr/ADR-003-keyboard-remapping-strategy.md), [ADR-007](../../../docs/adr/ADR-007-hyprland-configuration-modernization.md), [ADR-009](../../../docs/adr/ADR-009-browser-strategy.md), and [ADR-014](../../../docs/adr/ADR-014-macos-platform-parity.md).
