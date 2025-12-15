# Kids Laptop NixOS Configuration

A fully portable NixOS configuration for children's laptops with remote administration, Azure Key Vault secret management, and OneDrive file sync.

## Features

- 🔐 **Azure Key Vault**: All secrets stored in cloud, no local encryption needed
- ☁️ **OneDrive Sync**: Individual OneDrive per user (Drew, Emily, Bella)
- 🎮 **Gaming Ready**: Steam, Minecraft (PrismLauncher), Proton
- 🔧 **Remote Admin**: VS Code Remote SSH + full sudo access for Drew
- 📦 **Declarative**: Entire system in version control
- 🔄 **One-Command Restore**: `curl | bash` from fresh NixOS install

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
   curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash
   ```

3. **Login with Microsoft Account**
   - Follow the device code prompt
   - Login at https://microsoft.com/devicelogin
   - Script automatically fetches secrets and configures system

4. **Reboot**
   ```bash
   sudo reboot
   ```

Done! OneDrive will sync on first login.

## Setup Requirements

### Azure Key Vault Setup

1. Store rclone configs for each user (see [ONEDRIVE-SETUP.md](ONEDRIVE-SETUP.md)):
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

3. Encrypt it with agenix (see Secrets Management section)

### Secrets Management

All secrets are stored in Azure Key Vault. No local encryption needed!

**Required secrets in Key Vault:**
- `drew-rclone-config` - Drew's OneDrive configuration
- `emily-rclone-config` - Emily's OneDrive configuration
- `bella-rclone-config` - Bella's OneDrive configuration
- `drew-ssh-authorized-keys` - SSH keys for Drew
- `emily-ssh-authorized-keys` - SSH keys for Emily
- `bella-ssh-authorized-keys` - SSH keys for Bella

See [SETUP.md](SETUP.md) for detailed setup instructions.

## Repository Structure

```
.
├── bootstrap.sh                 # One-shot install script
├── flake.nix                    # Nix flake definition
├── configuration.nix            # System configuration
├── home-drew.nix                # Drew's home-manager config
├── home-emily.nix               # Emily's home-manager config
├── home-bella.nix               # Bella's home-manager config
├── hardware-configuration.nix   # Hardware-specific config
├── secrets/                     # Runtime secrets (not in git)
│   ├── drew-ssh-authorized-keys
│   ├── emily-ssh-authorized-keys
│   ├── bella-ssh-authorized-keys
│   ├── drew-rclone.conf
│   ├── emily-rclone.conf
│   └── bella-rclone.conf
├── README.md
├── SETUP.md
├── ONEDRIVE-SETUP.md
└── KEYVAULT-SECRETS.md
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
ssh drew@kids-laptop
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#kids-laptop
```

Or set up automatic updates (already configured in `configuration.nix`).

## Customization

- **Add packages**: Edit `home.nix` or `configuration.nix`
- **Change desktop environment**: Modify `services.xserver` in `configuration.nix`
- **Add secrets**: Create new `.age` files and reference in `secrets.nix`
- **Timezone/locale**: Update `configuration.nix`

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

## TODO

- [ ] Add disk encryption support (LUKS)
- [ ] Implement automatic backup schedule
- [ ] Add parental control profiles
- [ ] Create custom NixOS ISO with bootstrap embedded
- [ ] Add monitoring/alerting for system health

## License

MIT - Customize freely for your family's needs!
