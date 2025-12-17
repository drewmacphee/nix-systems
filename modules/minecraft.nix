{ config, pkgs, lib, ... }:

let
  cfg = config.modules.minecraft;
in
{
  options.modules.minecraft = {
    enable = lib.mkEnableOption "Minecraft/PrismLauncher setup";
    
    email = lib.mkOption {
      type = lib.types.str;
      description = "Microsoft account email for Minecraft";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Dynamically set RAM allocation and create Minecraft directories
    home.activation.setupMinecraft = config.lib.dag.entryAfter ["writeBoundary"] ''
      # Calculate RAM allocation based on system memory
      TOTAL_RAM_KB=$(${pkgs.gawk}/bin/awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo)
      TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
      MAX_RAM_MB=$((TOTAL_RAM_MB / 2))
      MIN_RAM_MB=$((TOTAL_RAM_MB / 4))
      
      # Ensure reasonable limits (min 2GB, max 16GB for safety)
      if [ "$MAX_RAM_MB" -lt 2048 ]; then
        MAX_RAM_MB=2048
      fi
      if [ "$MAX_RAM_MB" -gt 16384 ]; then
        MAX_RAM_MB=16384
      fi
      if [ "$MIN_RAM_MB" -lt 1024 ]; then
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
      
      echo "Minecraft RAM: Min ''${MIN_RAM_MB}MB / Max ''${MAX_RAM_MB}MB (Total System: ''${TOTAL_RAM_MB}MB)"
      
      # Create Minecraft directory structure in OneDrive
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/OneDrive/Minecraft/{instances,mods,icons,resourcepacks,screenshots}
      
      # Create helpful README
      $DRY_RUN_CMD cat > ${config.home.homeDirectory}/OneDrive/Minecraft/README.txt << 'EOF'
Minecraft Data for ${config.home.username}
============================================

This folder contains your Minecraft game data and syncs to OneDrive.

Your Microsoft account: ${cfg.email}

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
  };
}
