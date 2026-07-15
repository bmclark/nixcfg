# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Plymouth boot splash: manufacturer logo (bgrt) with Dracula background
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };
  boot.initrd.systemd.enable = true; # Required for smooth plymouth transitions

  networking.hostName = "maverick"; # Define your hostname.
  # networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.

  networking.networkmanager.enable = true;
  networking.networkmanager.unmanaged = ["interface-name:ve-*"];
  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    allowSFTP = true;
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true; # Required: launch via uwsm for proper systemd session management
    xwayland.enable = true;
  };

  # --- Login Manager (greetd + tuigreet) ---
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # Use uwsm to start Hyprland — avoids "not started via start-hyprland" warning
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # ----- ThinkPad X1 Carbon Gen 6 ------------------------------------------

  # Full linux-firmware (microcode completeness, Intel AC 8265 Wi-Fi firmware).
  # Already effectively on via other defaults, but set explicitly so it doesn't
  # depend on that.
  hardware.enableRedistributableFirmware = true;

  # TLP: battery charge thresholds + power management
  services.tlp = {
    enable = true;
    settings = {
      # Battery charge thresholds preserve long-term battery health.
      # Charging starts at 75%, stops at 80% when on AC.
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # CPU governor: powersave on battery, performance on AC
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # Intel CPU energy/performance policy (EPP)
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      # Intel turbo boost: on when plugged in, off on battery
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # WiFi power saving on battery
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # USB autosuspend
      USB_AUTOSUSPEND = 1;

      # Runtime PM for PCI(e) devices on battery
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # NVMe power saving
      AHCI_RUNTIME_PM_ON_AC = "on";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
    };
  };
  # Prevent conflicts: power-profiles-daemon and tlp are mutually exclusive
  services.power-profiles-daemon.enable = false;

  # Thermald: Intel thermal daemon for ThinkPad thermal management
  services.thermald.enable = true;

  # Firmware updates via fwupd (ThinkPads get BIOS/firmware updates via LVFS)
  services.fwupd.enable = true;

  # TrackPoint & touchpad tuning
  # The X1C6 has a good TrackPoint — bump sensitivity and enable tap-to-click on touchpad
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = false;
      disableWhileTyping = true;
      clickMethod = "clickfinger"; # 2-finger = right-click, 3-finger = middle
    };
  };

  # Fingerprint reader (Synaptics on X1C6)
  # Enroll with: fprintd-enroll
  services.fprintd.enable = true;

  # TrackPoint tuning (device name confirmed via /proc/bus/input/devices).
  # X1C6's TrackPoint is RMI4/I2C, not classic PS/2, so only a subset of
  # hardware.trackpoint's sysfs attributes actually exist on this device
  # (sensitivity, press_to_select, rate, resync_time) — no speed/inertia/reach/etc.
  hardware.trackpoint = {
    enable = true;
    device = "TPPS/2 Elan TrackPoint";
    sensitivity = 200; # default is 128; higher = more responsive to light pressure
  };

  # Brightness control (for waybar backlight module)
  environment.systemPackages = with pkgs; [
    git
    brightnessctl
    powertop # battery diagnostics: sudo powertop
    vulnix # CVE scanner: vulnix --system
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default # agenix CLI for secrets management
  ];

  # ----- Audio System (PipeWire) -----
  # PipeWire provides low-latency audio while keeping PulseAudio/JACK compatibility for legacy applications.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
  };

  # ----- Bluetooth -----
  # BlueZ with Blueman offers full-featured Bluetooth management with battery reporting for modern peripherals.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez.override {enableExperimental = true;};
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy.AutoEnable = true;
    };
  };
  services.blueman.enable = true;

  # ----- Desktop Environment Services -----
  # Provide desktop niceties like automounting, GVFS backends, and policy authentication prompts.
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  security.polkit.enable = true;

  # ----- XDG Portals -----
  # Enable Wayland portals for file picking, screenshots, and screen sharing integration.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
  };

  services.gnome.gnome-keyring.enable = true;
  services.tailscale.enable = true;

  programs.zsh.enable = true;

  networking.nat.enable = true;
  networking.nat.internalInterfaces = ["ve-+"];
  networking.nat.externalInterface = "enp1s0";

  security.sudo.extraConfig = "bclark ALL=(ALL) NOPASSWD: ALL";

  security.pam.services.login.enableGnomeKeyring = true;

  # ----- Firewall ----------------------------------------------------------
  # Allow SSH inbound only; all other inbound traffic is dropped.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
    allowedUDPPorts = [];
  };

  system.stateVersion = "24.11";
}
