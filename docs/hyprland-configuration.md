# Hyprland Configuration Guide

## Overview
The `maverick` laptop runs a modernized Hyprland environment managed through home-manager modules (`home/features/desktop/hyprland.nix` and `home/features/desktop/wayland.nix`). The configuration aligns with [ADR-003](adr/ADR-003-keyboard-remapping-strategy.md) for keyboard philosophy and [ADR-004](adr/ADR-004-theme-standardization.md) for Dracula theming, while the modernization work is captured in [ADR-007](adr/ADR-007-hyprland-configuration-modernization.md). Hyprland integrates tightly with PipeWire audio, BlueZ Bluetooth support, and desktop environment services such as udiskie and polkit for a polished, unix-porn-inspired experience.

In this guide, `Hyper` means the physical `Ctrl` key. `keyd` remaps physical `Ctrl` to Hyper/Mod3, while `CapsLock` becomes logical `Ctrl` for shell and editor shortcuts.
The shortcut tables below lead with the physical keys you actually press.

## Keyboard Shortcuts
Hyprland follows the shared keyboard strategy: logical `Ctrl` lives on `CapsLock` for applications, while `Hyper` on the physical `Ctrl` key owns window management.

### Window Management (Hyper)
| Physical key | Action |
|----------|--------|
| Ctrl+Return | Launch terminal (Ghostty) |
| Ctrl+D | Open wofi application launcher |
| Ctrl+E | Open Thunar file manager |
| Ctrl+Space | Toggle floating window state |
| Ctrl+F | Toggle fullscreen |
| Ctrl+W | Close active window |
| Ctrl+L | Lock screen with hyprlock |
| Ctrl+Escape | Open wlogout session menu |
| Alt+F4 | Close active window |

### Window Navigation
| Physical key | Action |
|----------|--------|
| Alt+Tab | Visual window switcher across all workspaces (hyprshell) |
| Ctrl+Comma | Focus window to the left |
| Ctrl+Period | Focus window to the right |
| Ctrl+Up | Focus window above |
| Ctrl+Down | Focus window below |

### Window Movement
| Physical key | Action |
|----------|--------|
| Ctrl+Shift+Comma | Move window left |
| Ctrl+Shift+Period | Move window right |
| Ctrl+Shift+Up | Move window up |
| Ctrl+Shift+Down | Move window down |
| Ctrl+Shift+Left | Move window to previous workspace |
| Ctrl+Shift+Right | Move window to next workspace |

### Workspace Management
| Physical key | Action |
|----------|--------|
| Ctrl+1..0 | Switch to workspace 1..10 |
| Ctrl+Shift+1..0 | Move window to workspace 1..10 |
| Ctrl+Left | Previous workspace |
| Ctrl+Right | Next workspace |
| CapsLock+Grave | Toggle the guake-style dropdown terminal (top third) |
| Ctrl+Mouse Wheel | Cycle workspaces |

### Resize Mode
| Physical key | Action |
|----------|--------|
| Ctrl+R | Enter resize mode |
| Left / Right / Up / Down | Resize active window (hold for continuous) |
| Escape | Exit resize mode |

### Screenshots
| Physical key | Action |
|----------|--------|
| Ctrl+Shift+S | Region screenshot (grim + slurp) |
| Ctrl+Shift+Print | Fullscreen screenshot |
| Ctrl+Alt+S | Region screenshot with annotation in Swappy |
| Ctrl+Alt+O | OCR selected region to clipboard |
| Ctrl+V | Open clipboard history picker |
| Ctrl+Shift+C | Pick a screen color to the clipboard |

### Wallpaper
| Physical key | Action |
|----------|--------|
| Ctrl+Shift+W | Set a random wallpaper |

### Media Keys
| Physical key | Action |
|----------|--------|
| Volume Up | Raise audio volume (+5%) |
| Volume Down | Lower audio volume (−5%) |
| Mute | Toggle audio mute |
| Mic Mute | Toggle microphone mute |
| Brightness Up | Increase screen brightness (+5%) |
| Brightness Down | Decrease screen brightness (−5%) |
| Play/Pause | Toggle media playback |
| Next | Skip to next track |
| Previous | Skip to previous track |

### Mouse Bindings
| Physical key | Action |
|----------|--------|
| Ctrl+Left Click | Move window |
| Ctrl+Right Click | Resize window |

## Configuration Files
- `home/features/desktop/hyprland.nix` — Core window manager configuration (keybindings, animations, window rules).  
- `home/features/desktop/wayland.nix` — Companion services (hyprpaper, hypridle, wofi, dunst, waybar, udiskie, etc.).  
- `hosts/maverick/configuration.nix` — System-level services (PipeWire, BlueZ, polkit, portals).  
Enable or disable modules via `home/bclark/maverick.nix` to tailor the desktop setup.

## Audio System
### PipeWire
- PipeWire provides a low-latency audio server with modern routing capabilities.  
- PulseAudio compatibility (`pipewire-pulse`) ensures legacy apps continue to function.  
- WirePlumber manages audio sessions; the Waybar `wireplumber` module exposes volume state.  
- Launch `pavucontrol` from the Waybar audio icon for detailed device control.  
- Verify PipeWire with `pactl info` or `systemctl --user status pipewire pipewire-pulse wireplumber`.

## Bluetooth
### BlueZ and Blueman
- BlueZ powers the Bluetooth stack with experimental features for battery readouts.  
- Blueman offers a GUI manager; click the Waybar Bluetooth icon or run `blueman-manager`.  
- Use `bluetoothctl` for CLI pairing: `scan on`, `pair <MAC>`, `connect <MAC>`.  
- Troubleshoot with `systemctl status bluetooth` and `rfkill list` (unblock if necessary).

## Wayland Ecosystem Services
### Wallpaper (swww)
- `swww` provides animated transitions; `hyprpaper` is disabled.
- Wallpapers live in `~/Pictures/papes/sfw/` and `~/Pictures/papes/nsfw/`.
- Switch mode: `wallpaper-mode sfw` or `wallpaper-mode nsfw`.
- Set a random wallpaper: `wallpaper-random` or `Ctrl+Shift+W`.
- Set a specific file: `wallpaper-set /path/to/image.png`.
- Wallpaper rotates automatically every 20 minutes via a systemd timer.

### Hypridle (Idle Management)
- Locks screen after 15 minutes, disables displays after 20 minutes, and restores DPMS on resume.  
- Customize timeouts or commands inside the `listener` list in `wayland.nix`.

### Wofi (Launcher)
- Themed with Dracula colors and transparency.  
- Controlled via Ctrl+D. Adjust style or behaviour in the `programs.wofi` section.

### Clipboard and OCR helpers
- `cliphist` stores clipboard history and `Ctrl+V` opens a picker.
- `ocr-screenshot`, `ocr-image`, and `ocr-pdf` extract text with `tesseract` and copy it to the clipboard.  
- `swappy` provides inline screenshot annotation for quick markups.

### Dunst (Notifications)
- Dracula colors across urgency levels; critical alerts stay until dismissed.  
- Test notifications with `notify-send "Test" "Message"`.

### Udiskie (Automounting)
- Automatically mounts removable media with user ownership and provides a tray icon.  
- Mounts appear at `/run/media/$USER/<LABEL>`. Configure additional rules via `services.udiskie.settings`.

### Polkit Agent
- Runs `polkit-gnome-authentication-agent-1` during graphical sessions to prompt for privilege escalation.  
- Check status with `systemctl --user status polkit-gnome-authentication-agent-1`.

### Waybar (Status Bar)
- Modules: workspaces, weather, active window, clock, network, wireplumber (audio), Bluetooth, battery, and system tray.  
- Dracula styling keeps modules consistent with the rest of the desktop.  
- Interactions: click audio for `pavucontrol`, Bluetooth for Blueman, tray for background services.  
- Customize modules in `programs.waybar.settings`.

## Desktop Environment Features
### File Management
- Thunar with `thunar-volman` (removable media) and `thunar-archive-plugin` (archives).  
- Thumbnail generation via Tumbler (enabled at the system level).  
- Ctrl+E opens Thunar.
- Custom actions add open-terminal-here, copy-path, OCR-image, and OCR-PDF helpers.

### Automounting
- udisks2 supplies backend support; udiskie handles user-level automounts.  
- Adjust mount options via `services.udiskie.settings.device_config` if needed.

### Network Management
- NetworkManager is enabled in the system configuration.  
- Waybar network module displays status, interface, and IP information.

## Aesthetics
### Blur Effects
- Blur size 6 with three passes, vibrancy 0.20, and xray mode create a glass effect that reveals blurred layers like Waybar.  
- Reduce `passes` or disable `xray` for better battery life.

### Shadows
- Soft shadows use range 18 and render power 3 for subtle depth; adjust in the `shadow` sub-block.

### Animations
- Custom bezier curves (`easeOutQuint`, `easeInOutCubic`, `quick`) tune window, workspace, and layer transitions.  
- Disable entirely by setting `animations.enabled = false` if performance is a concern.

### Rounding
- Window corners rounded to 12px for a modern look; modify `decoration.rounding` to suit preference.

### Dracula Theme Integration
- Colors originate from `home/themes/dracula.nix` to guarantee consistency.  
- `rgba` helper adds alpha support while keeping palette references readable.  
- Waybar, Wofi, Dunst, and Hyprland borders all consume the shared palette.

## Troubleshooting
- **Audio not working** — Check PipeWire services: `systemctl --user status pipewire pipewire-pulse wireplumber`. Inspect sinks with `pactl list sinks` or `wpctl status`.  
- **Bluetooth not working** — Ensure the service is active: `systemctl status bluetooth`; check `rfkill list`; pair via `bluetoothctl`.  
- **USB drives not automounting** — Verify `systemctl status udisks2` and `systemctl --user status udiskie`. Confirm the polkit agent is running.  
- **Authentication dialogs missing** — Restart the agent: `systemctl --user restart polkit-gnome-authentication-agent-1`. Confirm `security.polkit.enable = true`.  
- **Wallpaper not loading** — Confirm images exist in `~/Pictures/papes/{sfw,nsfw}/`. Check the swww daemon (`pgrep swww-daemon` or `swww query`) and run `wallpaper-random` manually to see errors.  
- **Idle lock not triggering** — Check `systemctl --user status hypridle` and ensure Hyprland systemd integration is enabled in `hyprland.nix`.  
- **Notifications not appearing** — Verify `systemctl --user status dunst` and test with `notify-send`.  
- **Blur missing on Waybar** — Ensure Waybar style uses transparent backgrounds and that `layerrule` blur entries are present in `hyprland.nix`.  
- **Performance issues** — Reduce blur passes, disable shadows, or tweak animation curves to lighten GPU load.

## Customization
- Adjust keybindings in `home/features/desktop/hyprland.nix` (`extraConfig` Lua block).
- Add or update window rules via `settings.window_rule` (Lua API 0.55.2 `hl.window_rule({...})` form).
- Tune blur, shadows, and animation curves inside `settings.config.decoration` and `settings.animation`.
- Modify Waybar modules by editing `programs.waybar.settings.mainbar` in `wayland.nix`.
- Choose default audio devices in `pavucontrol` or with `wpctl set-default`.
- Manage Bluetooth devices with Blueman (GUI) or `bluetoothctl` (CLI).
- Maintain Dracula color consistency by sourcing colors from `home/themes/dracula.nix`.

## References
- [ADR-003: Keyboard Remapping Strategy](adr/ADR-003-keyboard-remapping-strategy.md)
- [ADR-004: Theme Standardization](adr/ADR-004-theme-standardization.md)
- [ADR-007: Hyprland Configuration Modernization](adr/ADR-007-hyprland-configuration-modernization.md)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Home Manager Options](https://nix-community.github.io/home-manager/options.html)
- [Dracula Theme](https://draculatheme.com/)
- [PipeWire Documentation](https://docs.pipewire.org/)
- [WirePlumber Documentation](https://pipewire.pages.freedesktop.org/wireplumber/)
- [BlueZ Documentation](http://www.bluez.org/documentation/)
