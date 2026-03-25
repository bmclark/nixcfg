{
  pkgs,
  lib,
  inputs,
  outputs,
  config,
  ...
}:
with lib; let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  screenSharingCfg = config.remoteAccess.screenSharing;
  kickstart = "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart";
  allowedScreenSharingUsers =
    if screenSharingCfg.allowedUsers == []
    then [config.system.primaryUser]
    else screenSharingCfg.allowedUsers;
  allowedScreenSharingUsersCsv = concatStringsSep "," allowedScreenSharingUsers;
in {
  imports = [
    ./users
    ./alttab.nix
  ];

  options.remoteAccess.screenSharing = {
    enable = mkEnableOption "macOS Screen Sharing over the built-in VNC service";

    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["bclark"];
      description = ''
        Local macOS accounts allowed to authenticate to Screen Sharing.
        When left empty, the system primary user is allowed.
      '';
    };
  };

  config = mkMerge [
    {
      nixpkgs = {
        config.allowUnfree = true;
      };

      nix = {
        settings = {
          experimental-features = "nix-command flakes";
          trusted-users = [
            "root"
            "bclark"
          ];
        };
        gc = {
          automatic = true;
          options = "--delete-older-than 30d";
        };
        optimise.automatic = true;
        registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
        nixPath =
          ["/etc/nix/path"]
          ++ lib.mapAttrsToList (flakeName: _: "${flakeName}=flake:${flakeName}") flakeInputs;
      };

      programs.zsh.enable = true;

      # Use nix-darwin built-in service modules instead of manual launchd agents
      services.karabiner-elements.enable = true;
      services.aerospace.enable = true;
    }
    (mkIf screenSharingCfg.enable {
      assertions = [
        {
          assertion = allowedScreenSharingUsers != [];
          message = "remoteAccess.screenSharing.allowedUsers must contain at least one user.";
        }
      ];

      system.activationScripts.postActivation.text = mkAfter ''
        echo "configuring macOS Screen Sharing for ${allowedScreenSharingUsersCsv}" >&2

        # Disable Remote Management (ARD) — mutually exclusive with Screen Sharing
        ${kickstart} -deactivate -configure -access -off 2>/dev/null || true

        # Enable plain Screen Sharing (VNC on port 5900)
        /bin/launchctl enable system/com.apple.screensharing 2>/dev/null || true
        /bin/launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true

        # Restrict access to specified users via dscl
        ${concatMapStringsSep "\n        " (user:
          "/usr/bin/dscl . -merge /Groups/com.apple.access_screensharing GroupMembership ${escapeShellArg user}"
        ) allowedScreenSharingUsers}
      '';
    })
  ];
}
