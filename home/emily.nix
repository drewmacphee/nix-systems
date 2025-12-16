{ config, pkgs, ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/onedrive.nix
    ../modules/minecraft.nix
    ../modules/login-reminders.nix
    ../modules/packages/base.nix
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

  # Login reminders
  modules.loginReminders = {
    enable = true;
    accounts = {
      Chrome = {
        hint = "Sign in to Chrome with emilykamacphee@outlook.com";
        icon = "google-chrome";
        message = "Remember to sign in to Chrome:\n\nAccount: emilykamacphee@outlook.com\n\nThis will sync your bookmarks, extensions, and settings.";
      };
      Steam = {
        hint = "Sign in to Steam";
        icon = "steam";
        message = "Remember to sign in to Steam with your account.\n\nThis will sync your games and friends list.";
      };
      PrismLauncher = {
        hint = "Sign in to Minecraft with Microsoft account";
        icon = "prismlauncher";
        message = "Remember to sign in to PrismLauncher:\n\n1. Open PrismLauncher\n2. Click 'Accounts' → 'Add Microsoft'\n3. Sign in with: emilykamacphee@outlook.com\n\nYour worlds are synced to OneDrive!";
      };
    };
  };
}
