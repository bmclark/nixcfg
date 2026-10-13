# Entry point for the hangman NixOS configuration.
# DRAFT — hardware-configuration.nix must be generated at install time.
{...}: {
  imports = [
    ./configuration.nix
    ./disko.nix
    # ./hardware-configuration.nix  # uncomment after nixos-generate-config
    ../common/default.nix
  ];
}
