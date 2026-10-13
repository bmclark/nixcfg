# Dell Optiplex 9020 (i7-4790, 32 GB RAM, GTX 1650 -> VFIO passthrough).
# DRAFT — see docs/adr/ADR-015-optiplex-host-and-gpu-passthrough.md.
# Host graphics: Intel HD 4600 (i915). The 1650 is reserved for the Windows guest.
{
  pkgs,
  lib,
  ...
}: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "optiplex";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  # --- VFIO: bind GTX 1650 + its HDMI audio to vfio-pci at boot ------------
  # IDs confirmed via lspci -nn on hardware (2026-10-13 preflight):
  #   01:00.0 VGA  TU117 [GeForce GTX 1650]  10de:1f82
  #   01:00.1 Audio TU117 HD audio           10de:10fa
  boot.kernelParams = [
    "intel_iommu=on"
    "vfio-pci.ids=10de:1f82,10de:10fa"
  ];
  boot.extraModprobeConfig = "options vfio-pci ids=10de:1f82,10de:10fa";
  boot.initrd.kernelModules = ["vfio_pci" "vfio" "vfio_iommu_type1" "vfio_virqfd"];

  # --- Virtualisation -------------------------------------------------------
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # --- Desktop stack (mirrors maverick) ------------------------------------
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;
  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };
  services.tailscale.enable = true;

  programs.zsh.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
  };

  # This host has no wireless hardware; silence the wpa_supplicant warning.
  networking.wireless.enable = lib.mkForce false;

  system.stateVersion = "26.05";
}
