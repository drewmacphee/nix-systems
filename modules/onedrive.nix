{ config, pkgs, lib, ... }:

let
  cfg = config.modules.onedrive;
in
{
  options.modules.onedrive = {
    enable = lib.mkEnableOption "OneDrive sync service";
    
    email = lib.mkOption {
      type = lib.types.str;
      description = "OneDrive email address";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Helper script to fix authentication
    home.packages = [
      (pkgs.writeShellScriptBin "fix-onedrive" ''
        echo "Starting OneDrive configuration..."
        ${pkgs.rclone}/bin/rclone config
        echo "Restarting OneDrive service..."
        systemctl --user restart onedrive
        echo "Done! Checking status..."
        systemctl --user status onedrive
      '')
    ];

    # Check OneDrive status on login
    home.file.".config/autostart/onedrive-check.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=OneDrive Check
      Exec=${pkgs.writeShellScript "check-onedrive" ''
        if ! ${pkgs.rclone}/bin/rclone lsd onedrive: --max-depth 1 --config ${config.home.homeDirectory}/.config/rclone/rclone.conf >/dev/null 2>&1; then
           ${pkgs.libnotify}/bin/notify-send -u critical -t 0 "OneDrive Disconnected" "Run 'fix-onedrive' in a terminal to re-authenticate."
        fi
      ''}
      Hidden=false
      NoDisplay=false
      X-GNOME-Autostart-enabled=true
    '';

    # OneDrive systemd service
    systemd.user.services.onedrive = {
      Unit = {
        Description = "OneDrive Sync Service";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.rclone}/bin/rclone mount onedrive: ${config.home.homeDirectory}/OneDrive --vfs-cache-mode writes --config ${config.home.homeDirectory}/.config/rclone/rclone.conf";
        ExecStop = "/run/current-system/sw/bin/fusermount -u ${config.home.homeDirectory}/OneDrive";
        Restart = "on-failure";
        RestartSec = "10s";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
    
    # Create OneDrive mount point
    home.file."OneDrive/.keep".text = "";
  };
}
