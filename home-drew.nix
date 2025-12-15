{ config, pkgs, ... }:

{
  imports = [
    ./modules/common.nix
    ./modules/onedrive.nix
    ./modules/minecraft.nix
    ./modules/login-reminders.nix
    ./modules/packages/base.nix
    ./modules/packages/dev.nix
  ];

  # User identity
  home.username = "drew";
  home.homeDirectory = "/home/drew";

  # Git user configuration
  programs.git = {
    userName = "Drew MacPhee";
    userEmail = "1778064+drewmacphee@users.noreply.github.com";
  };

  # OneDrive configuration
  modules.onedrive = {
    enable = true;
    email = "drewjamesross@outlook.com";
  };

  # Minecraft configuration
  modules.minecraft = {
    enable = true;
    email = "drewjamesross@outlook.com";
  };

  # Login reminders
  modules.loginReminders = {
    enable = true;
    accounts = {
      Chrome = {
        hint = "Sign in to Chrome with drewjamesross@outlook.com";
        icon = "google-chrome";
        message = "Remember to sign in to Chrome:\n\nAccount: drewjamesross@outlook.com\n\nThis will sync your bookmarks, extensions, and settings.";
      };
      Steam = {
        hint = "Sign in to Steam";
        icon = "steam";
        message = "Remember to sign in to Steam with your account.\n\nThis will sync your games and friends list.";
      };
      PrismLauncher = {
        hint = "Sign in to Minecraft with Microsoft account";
        icon = "prismlauncher";
        message = "Remember to sign in to PrismLauncher:\n\n1. Open PrismLauncher\n2. Click 'Accounts' → 'Add Microsoft'\n3. Sign in with: drewjamesross@outlook.com\n\nYour worlds are synced to OneDrive!";
      };
    };
  };
}
