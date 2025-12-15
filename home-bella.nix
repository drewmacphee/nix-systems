{ config, pkgs, ... }:

{
  home.username = "bella";
  home.homeDirectory = "/home/bella";
  home.stateVersion = "24.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Bella";
    userEmail = "bella@example.com";
  };

  # Bash configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      update = "sudo nixos-rebuild switch --flake /etc/nixos#kids-laptop";
    };
  };

  # User packages
  home.packages = with pkgs; [
    firefox
    vlc
    libreoffice
    gimp
    inkscape
    
    # Educational software
    gcompris
    tuxpaint
    stellarium
    
    # Development tools
    python3
    nodejs
  ];

  # OneDrive systemd service
  systemd.user.services.onedrive = {
    Unit = {
      Description = "OneDrive Sync Service";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.rclone}/bin/rclone mount onedrive: /home/bella/OneDrive --vfs-cache-mode writes --config /home/bella/.config/rclone/rclone.conf";
      ExecStop = "/run/current-system/sw/bin/fusermount -u /home/bella/OneDrive";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Create OneDrive mount point
  home.file."OneDrive/.keep".text = "";

  # VS Code settings
  programs.vscode = {
    enable = true;
  };
}
