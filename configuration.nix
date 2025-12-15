{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "bazztop";
  networking.networkmanager.enable = true;
  
  # Automatic WiFi connection from secrets
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ "/etc/nixos/secrets/wifi-env" ];
    profiles = {
      home = {
        connection = {
          id = "Home WiFi";
          type = "wifi";
          autoconnect = true;
        };
        wifi = {
          ssid = "$WIFI_SSID";
          mode = "infrastructure";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$WIFI_PASSWORD";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
  
  # Enable mDNS for LAN discovery (Minecraft, etc.)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Timezone and locale
  # Timezone with automatic detection
  time.timeZone = "America/New_York";
  services.geoclue2.enable = true;
  services.automatic-timezoned.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable X11 and KDE Plasma
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Enable sound
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable OpenSSH for remote administration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      22      # SSH
      25565   # Minecraft server default
    ];
    allowedUDPPorts = [
      5353    # mDNS for LAN discovery
      24454   # Minecraft LAN discovery
    ];
    # Allow LAN discovery broadcasts
    allowedUDPPortRanges = [
      { from = 24454; to = 24454; }  # Minecraft LAN
    ];
  };

  # User accounts
  users.users.drew = {
    isNormalUser = true;
    description = "Drew (Admin)";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keyFiles = [ "/etc/nixos/secrets/drew-ssh-authorized-keys" ];
  };

  users.users.emily = {
    isNormalUser = true;
    description = "Emily";
    extraGroups = [ "networkmanager" ];
    openssh.authorizedKeys.keyFiles = [ "/etc/nixos/secrets/emily-ssh-authorized-keys" ];
  };

  users.users.bella = {
    isNormalUser = true;
    description = "Bella";
    extraGroups = [ "networkmanager" ];
    openssh.authorizedKeys.keyFiles = [ "/etc/nixos/secrets/bella-ssh-authorized-keys" ];
  };

  # Allow sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Enable Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    azure-cli
    rclone
    
    # Gaming and applications for all users
    prismlauncher
    google-chrome
    vscode
    protonup-qt
  ];

  # Setup rclone configs for all users from bootstrap secrets
  system.activationScripts.setupSecrets = ''
    # Create secrets directory in /etc/nixos if it doesn't exist
    mkdir -p /etc/nixos/secrets
    
    # Copy secrets from bootstrap location if they exist
    if [ -d /tmp/nixos-secrets ]; then
      cp -f /tmp/nixos-secrets/* /etc/nixos/secrets/ 2>/dev/null || true
    fi
    
    # Setup rclone configs for each user
    for user in drew emily bella; do
      user_home=$(eval echo ~$user)
      if [ -d "$user_home" ]; then
        mkdir -p "$user_home/.config/rclone"
        if [ -f "/etc/nixos/secrets/$user-rclone.conf" ]; then
          cp /etc/nixos/secrets/$user-rclone.conf "$user_home/.config/rclone/rclone.conf"
          chown -R $user:users "$user_home/.config/rclone"
          chmod 600 "$user_home/.config/rclone/rclone.conf"
        fi
      fi
    done
    
    # Set proper permissions on SSH keys
    chmod 644 /etc/nixos/secrets/*-ssh-authorized-keys 2>/dev/null || true
  '';

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Automatic system updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;  # Never auto-reboot (could interrupt gaming)
    dates = "03:00";      # Check for updates at 3am daily
    flake = "github:drewmacphee/nix-kids-laptop";
    flags = [
      "--update-input" "nixpkgs"
      "--update-input" "home-manager"
      "--commit-lock-file"
    ];
  };

  # Automatic garbage collection (cleanup old generations)
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Keep last 10 boot entries for rollback
  boot.loader.systemd-boot.configurationLimit = 10;

  system.stateVersion = "24.05";
}
