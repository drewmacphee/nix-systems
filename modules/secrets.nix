# Secrets management using systemd-creds
# Secrets are encrypted locally with TPM/hardware and never stored in git
{ config, lib, pkgs, ... }:

let
  credsDir = "/etc/credstore.encrypted";
  
  # Helper to create a systemd service that decrypts a credential
  mkCredentialService = { name, user, destination, mode ? "0600" }: {
    description = "Decrypt ${name} credential for ${user}";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "decrypt-${name}" ''
        mkdir -p $(dirname ${destination})
        ${pkgs.systemd}/bin/systemd-creds decrypt \
          ${credsDir}/${name}.cred - > ${destination}
        chmod ${mode} ${destination}
        chown ${user}:users ${destination}
      '';
    };
  };
in
{
  # Services to decrypt credentials on boot
  systemd.services = {
    # Rclone configs
    "decrypt-drew-rclone" = mkCredentialService {
      name = "drew-rclone";
      user = "drew";
      destination = "/home/drew/.config/rclone/rclone.conf";
    };
    
    "decrypt-emily-rclone" = mkCredentialService {
      name = "emily-rclone";
      user = "emily";
      destination = "/home/emily/.config/rclone/rclone.conf";
    };
    
    "decrypt-bella-rclone" = mkCredentialService {
      name = "bella-rclone";
      user = "bella";
      destination = "/home/bella/.config/rclone/rclone.conf";
    };
    
    # SSH authorized keys
    "decrypt-drew-ssh" = {
      description = "Decrypt drew SSH keys";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "decrypt-drew-ssh" ''
          install -d -m 0700 -o drew -g users /home/drew/.ssh
          ${pkgs.systemd}/bin/systemd-creds decrypt \
            ${credsDir}/drew-ssh-authorized-keys.cred - > /home/drew/.ssh/authorized_keys
          chown drew:users /home/drew/.ssh/authorized_keys
          chmod 600 /home/drew/.ssh/authorized_keys
        '';
      };
    };
    
    "decrypt-emily-ssh" = {
      description = "Decrypt emily SSH keys";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "decrypt-emily-ssh" ''
          install -d -m 0700 -o emily -g users /home/emily/.ssh
          ${pkgs.systemd}/bin/systemd-creds decrypt \
            ${credsDir}/emily-ssh-authorized-keys.cred - > /home/emily/.ssh/authorized_keys
          chown emily:users /home/emily/.ssh/authorized_keys
          chmod 600 /home/emily/.ssh/authorized_keys
        '';
      };
    };
    
    "decrypt-bella-ssh" = {
      description = "Decrypt bella SSH keys";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "decrypt-bella-ssh" ''
          install -d -m 0700 -o bella -g users /home/bella/.ssh
          ${pkgs.systemd}/bin/systemd-creds decrypt \
            ${credsDir}/bella-ssh-authorized-keys.cred - > /home/bella/.ssh/authorized_keys
          chown bella:users /home/bella/.ssh/authorized_keys
          chmod 600 /home/bella/.ssh/authorized_keys
        '';
      };
    };
  };
  
  # Ensure parent directories exist
  systemd.tmpfiles.rules = [
    "d /home/drew/.config/rclone 0700 drew users -"
    "d /home/emily/.config/rclone 0700 emily users -"
    "d /home/bella/.config/rclone 0700 bella users -"
    "d /home/drew/.ssh 0700 drew users -"
    "d /home/emily/.ssh 0700 emily users -"
    "d /home/bella/.ssh 0700 bella users -"
  ];
}
