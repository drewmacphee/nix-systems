# Kids Laptop NixOS Configuration

A fully portable NixOS configuration for multiple machines with remote administration, Azure Key Vault secret management, and OneDrive file sync.

## Features

- 🔐 **Azure Key Vault**: All secrets stored in cloud, no local encryption needed
- ☁️ **OneDrive Sync**: Individual OneDrive per user (Drew, Emily, Bella)
- 🎮 **Gaming Ready**: Steam, Minecraft (PrismLauncher), Proton
- 🔧 **Remote Admin**: VS Code Remote SSH + full sudo access for Drew
- 📦 **Declarative**: Entire system in version control
- 🔄 **One-Command Restore**: `curl | bash` from fresh NixOS install
- 🖥️ **Multi-Machine**: Support for multiple machines with shared config

## Multi-Machine Structure

- `modules/` - Shared configuration for all machines
- `home/` - User-specific home-manager configurations
- `hosts/bazztop/` - Configuration for the bazztop laptop
- `hosts/*/hardware-configuration.nix` - Machine-specific hardware (auto-generated)

## Users

- **Drew** (drewjamesross@outlook.com) - Admin with sudo
- **Emily** (emilykamacphee@outlook.com) - Standard user  
- **Bella** (isabellaleblanc@outlook.com) - Standard user

## Quick Start - Fresh Install

1. **Install NixOS Minimal**
   - Boot from NixOS installer USB
   - Follow standard installation (partition, mount, generate config)
   - Install with basic packages: `nixos-install`
   - Reboot into the new system

2. **Run Bootstrap Script**
   ```bash
   curl -L https://raw.githubusercontent.com/drewmacphee/nix-systems/main/bootstrap.sh | sudo bash
   ```
   
   - Select a machine from the menu (bazztop or new machine)
   - For new machines, enter a hostname and update flake.nix later

3. **Login with Microsoft Account**
   - Follow the device code prompt
   - Login at https://microsoft.com/devicelogin
   - Complete MFA authentication
   - Script automatically fetches secrets and configures system

4. **Reboot**
   ```bash
   sudo reboot
   ```

Done! OneDrive will sync on first login.

## Adding a New Machine

1. Create `hosts/newmachine/configuration.nix`:
   ```nix
   { config, pkgs, ... }:
   {
     imports = [ 
       ./hardware-configuration.nix 
       ../../modules/common.nix
     ];
     
     networking.hostName = "newmachine";
   }
   ```

2. Add placeholder `hosts/newmachine/hardware-configuration.nix`:
   ```nix
   { config, lib, pkgs, modulesPath, ... }:
   {
     imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
     boot.loader.grub.enable = true;
     boot.loader.grub.device = "/dev/sda";
   }
   ```

3. Update `flake.nix`:
   ```nix
   nixosConfigurations = {
     bazztop = mkSystem "bazztop";
     newmachine = mkSystem "newmachine";  # Add this
   };
   ```

4. Commit, push, and run bootstrap on new machine

## Documentation

- **[docs/SETUP-SIMPLIFIED.md](docs/SETUP-SIMPLIFIED.md)** - Complete setup walkthrough
- **[docs/SECRETS-SYSTEMD-CREDS.md](docs/SECRETS-SYSTEMD-CREDS.md)** - Secrets management architecture
- **[docs/KEYVAULT-SETUP-GUIDE.md](docs/KEYVAULT-SETUP-GUIDE.md)** - Azure Key Vault configuration
- **[docs/ONEDRIVE-SETUP.md](docs/ONEDRIVE-SETUP.md)** - OneDrive integration guide
- **[docs/MINECRAFT-SETUP-GUIDE.md](docs/MINECRAFT-SETUP-GUIDE.md)** - Minecraft/PrismLauncher config
- **[docs/MINECRAFT-LAN-GUIDE.md](docs/MINECRAFT-LAN-GUIDE.md)** - LAN multiplayer setup
- **[docs/WIFI-SETUP.md](docs/WIFI-SETUP.md)** - WiFi automation
- **[docs/UPDATES-AND-MAINTENANCE.md](docs/UPDATES-AND-MAINTENANCE.md)** - System maintenance

## Setup Requirements

### Azure Key Vault Setup

1. Store rclone configs for each user (see [docs/ONEDRIVE-SETUP.md](docs/ONEDRIVE-SETUP.md)):
   ```bash
   az keyvault secret set --vault-name nix-kids-laptop --name drew-rclone-config --file ~/.config/rclone/rclone.conf
   az keyvault secret set --vault-name nix-kids-laptop --name emily-rclone-config --file ~/.config/rclone/rclone.conf
   az keyvault secret set --vault-name nix-kids-laptop --name bella-rclone-config --file ~/.config/rclone/rclone.conf
   ```

2. Store SSH authorized keys:
   ```bash
   cat ~/.ssh/id_ed25519.pub > /tmp/authorized_keys
   az keyvault secret set --vault-name nix-kids-laptop --name drew-ssh-authorized-keys --file /tmp/authorized_keys
   az keyvault secret set --vault-name nix-kids-laptop --name emily-ssh-authorized-keys --file /tmp/authorized_keys
   az keyvault secret set --vault-name nix-kids-laptop --name bella-ssh-authorized-keys --file /tmp/authorized_keys
   ```

3. Store user passwords and WiFi credentials:
   ```bash
   az keyvault secret set --vault-name nix-kids-laptop --name drew-password --value "SecurePassword123"
   az keyvault secret set --vault-name nix-kids-laptop --name wifi-ssid --value "1054"
   az keyvault secret set --vault-name nix-kids-laptop --name wifi-password --value "YourWiFiPassword"
   ```

### OneDrive Setup

1. Configure rclone for OneDrive:
   ```bash
   rclone config
   # Choose: onedrive -> Microsoft OneDrive -> follow prompts
   ```

2. Export the config:
   ```bash
   cat ~/.config/rclone/rclone.conf
   ```

3. Upload it to Azure Key Vault (recommended):
   - See [docs/KEYVAULT-SETUP-GUIDE.md](docs/KEYVAULT-SETUP-GUIDE.md)

### Secrets Management

**Hybrid approach for maximum security:**

1. **Storage**: Azure Key Vault (`nix-kids-laptop`) - source of truth
2. **Bootstrap**: Fetches secrets during initial setup
3. **Local**: Encrypted with `systemd-creds` (TPM/hardware-bound)
4. **Runtime**: Decrypted on boot via systemd services
5. **Security**: Never in git, survives reboots, cleared on reinstall

**Required secrets in Key Vault:**
- `drew-rclone-config`, `emily-rclone-config`, `bella-rclone-config` - OneDrive configurations
- `drew-ssh-authorized-keys`, `emily-ssh-authorized-keys`, `bella-ssh-authorized-keys` - SSH authorized keys
- `drew-password`, `emily-password`, `bella-password` - User passwords
- `wifi-ssid`, `wifi-password` - WiFi credentials

See [docs/KEYVAULT-SETUP-GUIDE.md](docs/KEYVAULT-SETUP-GUIDE.md) for setup instructions.

## Repository Structure

```
.
├── bootstrap.sh                    # One-shot install script
├── flake.nix                       # Nix flake definition
├── flake.lock                      # Pinned dependencies
├── hosts/                          # Machine-specific configs
│   └── bazztop/
│       ├── configuration.nix       # Host config (networking, etc)
│       └── hardware-configuration.nix  # Auto-generated hardware config
├── modules/                        # Shared configuration modules
│   ├── common.nix                  # System-wide settings (users, packages)
│   ├── home-manager.nix            # Home-manager integration
│   └── minecraft.nix               # Minecraft/PrismLauncher setup
├── home/                           # User home-manager configs
│   ├── drew.nix                    # Drew's config
│   ├── emily.nix                   # Emily's config
│   └── bella.nix                   # Bella's config
├── docs/                           # Documentation
│   ├── SETUP-SIMPLIFIED.md
│   ├── KEYVAULT-SETUP-GUIDE.md
│   ├── ONEDRIVE-SETUP.md
│   ├── MINECRAFT-SETUP-GUIDE.md
│   ├── MINECRAFT-LAN-GUIDE.md
│   ├── WIFI-SETUP.md
│   └── UPDATES-AND-MAINTENANCE.md
└── README.md                       # This file
```

## Remote Administration

Once installed, connect via VS Code Remote SSH:

1. Install "Remote - SSH" extension in VS Code
2. Add SSH config:
   ```
   Host kids-laptop
     HostName <laptop-ip>
     User drew
     IdentityFile ~/.ssh/id_ed25519
   ```
3. Connect via Command Palette: "Remote-SSH: Connect to Host"

## Updating the System

From remote machine:
```bash
ssh drew@bazztop
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#bazztop
```

Automatic updates are configured to run daily at 3 AM. See [docs/UPDATES-AND-MAINTENANCE.md](docs/UPDATES-AND-MAINTENANCE.md) for details.

## Customization

- **Add packages**: Edit `modules/common.nix`
- **Change desktop environment**: Modify `services.desktopManager.plasma6.enable` in `modules/common.nix`
- **Add secrets**: Store in Azure Key Vault, fetch in `bootstrap.sh`
- **Timezone**: Auto-detected via geoclue2 (configured in `modules/common.nix`)
- **Add user**: Create new `home/username.nix` (see existing as template)

## Troubleshooting

**Bootstrap fails to fetch secrets:**
- Ensure you're logged into the correct Azure subscription
- Verify Key Vault name and secret name match
- Check Key Vault access policies

**OneDrive not mounting:**
- Verify rclone config is valid
- Check `systemctl --user status onedrive`
- Test manually: `rclone lsd onedrive:`

**SSH connection refused:**
- Ensure firewall allows port 22
- Check `systemctl status sshd`
- Verify SSH keys are correctly deployed

## Features Highlights

✅ **Modular Configuration**: 80% less code through shared modules  
✅ **Dynamic RAM**: Minecraft allocates RAM based on system memory  
✅ **Automatic Updates**: Daily system updates at 3 AM  
✅ **LAN Discovery**: mDNS for Minecraft multiplayer  
✅ **WiFi Automation**: Pre-configured WiFi in bootstrap  
✅ **SSH Hardening**: Key-only auth, passwords disabled for remote access  
✅ **Per-User OneDrive**: Individual cloud storage with automatic mounting  
✅ **Gaming Ready**: Steam, Proton, PrismLauncher with OneDrive sync

## License

MIT - Customize freely for your family's needs!
