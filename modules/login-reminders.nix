{ config, pkgs, lib, ... }:

let
  cfg = config.modules.loginReminders;
in
{
  options.modules.loginReminders = {
    enable = lib.mkEnableOption "Login reminder desktop files";
    
    accounts = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Account reminders to create";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Create desktop files with login reminders
    home.file = lib.mapAttrs' (name: account: 
      lib.nameValuePair "Desktop/Login-${name}.desktop" {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=⚠️ Login to ${name}
          Comment=${account.hint}
          Icon=${account.icon}
          Exec=sh -c 'kdialog --msgbox "${account.message}"'
          Terminal=false
          Categories=Utility;
        '';
      }
    ) cfg.accounts;
  };
}
