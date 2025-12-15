{ config, pkgs, ... }:

{
  imports = [
    ./modules/common.nix
    ./modules/onedrive.nix
    ./modules/minecraft.nix
    ./modules/packages/base.nix
  ];

  # User identity
  home.username = "bella";
  home.homeDirectory = "/home/bella";

  # Git user configuration
  programs.git = {
    userName = "Bella";
    userEmail = "bella@example.com";
  };

  # OneDrive configuration
  modules.onedrive = {
    enable = true;
    email = "isabellaleblanc@outlook.com";
  };

  # Minecraft configuration
  modules.minecraft = {
    enable = true;
    email = "isabellaleblanc@outlook.com";
  };
}
