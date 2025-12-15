{ config, pkgs, ... }:

{
  imports = [
    ./modules/common.nix
    ./modules/onedrive.nix
    ./modules/minecraft.nix
    ./modules/packages/base.nix
  ];

  # User identity
  home.username = "emily";
  home.homeDirectory = "/home/emily";

  # Git user configuration
  programs.git = {
    userName = "Emily";
    userEmail = "emily@example.com";
  };

  # OneDrive configuration
  modules.onedrive = {
    enable = true;
    email = "emilykamacphee@outlook.com";
  };

  # Minecraft configuration
  modules.minecraft = {
    enable = true;
    email = "emilykamacphee@outlook.com";
  };
}
