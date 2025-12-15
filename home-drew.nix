{ config, pkgs, ... }:

{
  home.username = "drew";
  home.homeDirectory = "/home/drew";
  home.stateVersion = "24.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Drew";
    userEmail = "drew@example.com";
  };

  # Bash configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      update = "sudo nixos-rebuild switch --flake /etc/nixos#nix-kids-laptop";
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
      ExecStart = "${pkgs.rclone}/bin/rclone mount onedrive: /home/drew/OneDrive --vfs-cache-mode writes --config /home/drew/.config/rclone/rclone.conf";
      ExecStop = "/run/current-system/sw/bin/fusermount -u /home/drew/OneDrive";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Create OneDrive mount point
  home.file."OneDrive/.keep".text = "";

  # VS Code settings for remote development
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      ms-vscode-remote.remote-ssh
    ];
  };

  # PrismLauncher configuration - point to OneDrive
  # Calculate RAM allocation: use 50% of system RAM for max, 25% for min
  home.file.".local/share/PrismLauncher/prismlauncher.cfg".text = 
    let
      # Get total system memory in MB (will be calculated at build time)
      # This uses a reasonable default, actual calculation happens via activation script
      totalRamMB = 8192; # Fallback default
      maxRamMB = totalRamMB / 2; # 50% of total RAM
      minRamMB = totalRamMB / 4; # 25% of total RAM
    in ''
    [General]
    InstanceDir=${config.home.homeDirectory}/OneDrive/Minecraft/instances
    IconsDir=${config.home.homeDirectory}/OneDrive/Minecraft/icons
    CentralModsDir=${config.home.homeDirectory}/OneDrive/Minecraft/mods
    
    [Java]
    MaxMemAlloc=${toString maxRamMB}
    MinMemAlloc=${toString minRamMB}
    PermGen=128
  '';

  # Dynamically set RAM allocation based on actual system memory
  home.activation.setupMinecraftRAM = config.lib.dag.entryAfter ["writeBoundary"] ''
    # Calculate RAM allocation based on system memory
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
    MAX_RAM_MB=$((TOTAL_RAM_MB / 2))
    MIN_RAM_MB=$((TOTAL_RAM_MB / 4))
    
    # Ensure reasonable limits (min 2GB, max 16GB for safety)
    if [ $MAX_RAM_MB -lt 2048 ]; then
      MAX_RAM_MB=2048
    fi
    if [ $MAX_RAM_MB -gt 16384 ]; then
      MAX_RAM_MB=16384
    fi
    if [ $MIN_RAM_MB -lt 1024 ]; then
      MIN_RAM_MB=1024
    fi
    
    # Update PrismLauncher config with dynamic values
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.local/share/PrismLauncher
    $DRY_RUN_CMD cat > ${config.home.homeDirectory}/.local/share/PrismLauncher/prismlauncher.cfg << EOF
[General]
InstanceDir=${config.home.homeDirectory}/OneDrive/Minecraft/instances
IconsDir=${config.home.homeDirectory}/OneDrive/Minecraft/icons
CentralModsDir=${config.home.homeDirectory}/OneDrive/Minecraft/mods

[Java]
MaxMemAlloc=$MAX_RAM_MB
MinMemAlloc=$MIN_RAM_MB
PermGen=128
EOF
    
    echo "Minecraft RAM: Min ${MIN_RAM_MB}MB / Max ${MAX_RAM_MB}MB (Total System: ${TOTAL_RAM_MB}MB)"
  '';

  # Create Minecraft directory structure in OneDrive
  home.activation.setupMinecraft = config.lib.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/OneDrive/Minecraft/{instances,mods,icons,resourcepacks,screenshots}
    
    # Create helpful README
    $DRY_RUN_CMD cat > ${config.home.homeDirectory}/OneDrive/Minecraft/README.txt << 'EOF'
Minecraft Data for Drew
=======================

This folder contains your Minecraft game data and syncs to OneDrive.

Your Microsoft account: drewjamesross@outlook.com

On first launch of PrismLauncher:
1. Click "Profiles" in the top menu
2. Click "Manage Accounts"
3. Click "Add Microsoft"
4. Login with your Microsoft account
5. Create your first instance!

All your worlds, screenshots, and settings will be saved here
and automatically backed up to OneDrive.

Happy mining!
EOF
  '';
}
