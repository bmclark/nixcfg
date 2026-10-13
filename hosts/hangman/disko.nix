# Declarative disk layout for hangman (Dell Optiplex 9020).
# LUKS2 + btrfs, mirroring maverick's scheme with a cleaner subvol split.
#
# MANAGES /dev/sda ONLY. sdb (Windows 10, passed to VM) and sdc (bulk HDD)
# are deliberately untouched — disko never sees them.
#
# Apply from the installer ISO:
#   sudo nix run github:nix-community/disko -- \
#     --mode destroy,format,mount ./hosts/hangman/disko.nix
# (DESTROYS everything on /dev/sda.)
{
  lib,
  ...
}: {
  disko.devices = {
    disk.sda = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings = {
                allowDiscards = true;
                crypttabExtraOpts = ["fido2-device=auto"]; # no-op on TPM1.2-only hardware; harmless
              };
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime" "noexec"];
                  };
                  "/var-log" = {
                    mountpoint = "/var/log";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # zram swap (same policy as maverick): 32G RAM desktop, no hibernation.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };
}
