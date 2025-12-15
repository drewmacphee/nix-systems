# Quick Start Guide

The fastest way to get your kids' laptop configured!

## What You Need

- ✅ Azure account with Key Vault: `https://nix-kids-laptop.vault.azure.net/`
- ✅ GitHub account: `drewmacphee`
- ✅ 3 OneDrive accounts configured

## One-Time Setup (Do This Once)

### 1. Configure OneDrive for Each User

```bash
# Install rclone
nix-shell -p rclone

# Configure for Drew
rclone config  # Login with: drewjamesross@outlook.com
az keyvault secret set --vault-name nix-kids-laptop --name drew-rclone-config --file ~/.config/rclone/rclone.conf

# Configure for Emily
rm ~/.config/rclone/rclone.conf
rclone config  # Login with: emilykamacphee@outlook.com
az keyvault secret set --vault-name nix-kids-laptop --name emily-rclone-config --file ~/.config/rclone/rclone.conf

# Configure for Bella
rm ~/.config/rclone/rclone.conf
rclone config  # Login with: isabellaleblanc@outlook.com
az keyvault secret set --vault-name nix-kids-laptop --name bella-rclone-config --file ~/.config/rclone/rclone.conf
```

### 2. Store SSH Keys

```bash
# Use your SSH public key for remote access
cat ~/.ssh/id_ed25519.pub > /tmp/authorized_keys

az keyvault secret set --vault-name nix-kids-laptop --name drew-ssh-authorized-keys --file /tmp/authorized_keys
az keyvault secret set --vault-name nix-kids-laptop --name emily-ssh-authorized-keys --file /tmp/authorized_keys
az keyvault secret set --vault-name nix-kids-laptop --name bella-ssh-authorized-keys --file /tmp/authorized_keys

rm /tmp/authorized_keys
```

### 3. Push to GitHub

```bash
cd /path/to/nix-kids-laptop
git init
git add .
git commit -m "Initial configuration"
git remote add origin https://github.com/drewmacphee/nix-kids-laptop.git
git branch -M main
git push -u origin main
```

## Every Time You Restore the Laptop

### 1. Install NixOS Minimal

Boot from USB, partition disk, run standard NixOS install.

### 2. Run Bootstrap Script

```bash
curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash
```

### 3. Login to Azure

Follow the device code prompt, login at https://microsoft.com/devicelogin

### 4. Wait & Reboot

Script downloads everything and configures the system. Then:

```bash
sudo reboot
```

**Done!** All three users have:
- Their own OneDrive mounted at `~/OneDrive`
- SSH access configured
- Steam, Minecraft (PrismLauncher), Chrome, VS Code installed
- Educational software ready to use

## What Gets Installed

**System:**
- GNOME desktop
- Steam with Proton
- OpenSSH server
- NetworkManager

**For All Users:**
- PrismLauncher (Minecraft)
- Google Chrome
- VS Code
- LibreOffice
- GIMP, Inkscape
- VLC
- Firefox
- Educational apps (GCompris, TuxPaint, Stellarium)
- Python, Node.js

**Per User:**
- Individual OneDrive account mounted
- Separate SSH access
- Own home directory

## Remote Access

After install, connect with VS Code:

```
Host kids-laptop
  HostName <laptop-ip>
  User drew
  IdentityFile ~/.ssh/id_ed25519
```

## Updating Configuration

```bash
# Edit files locally
cd /path/to/nix-kids-laptop
vim configuration.nix

# Commit and push
git add .
git commit -m "Updated configuration"
git push

# On the laptop
ssh drew@kids-laptop
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#kids-laptop
```

## Updating Secrets

When OneDrive tokens expire or you need to change SSH keys:

```bash
# Update in Key Vault
az keyvault secret set --vault-name nix-kids-laptop --name drew-rclone-config --file ~/.config/rclone/rclone.conf

# Rebuild on laptop
ssh drew@kids-laptop
sudo nixos-rebuild switch --flake /etc/nixos#kids-laptop
```

No git commits needed for secrets!

## Troubleshooting

**OneDrive not mounting?**
```bash
systemctl --user status onedrive
journalctl --user -u onedrive -f
```

**Can't SSH in?**
```bash
# Check SSH is running
systemctl status sshd

# Check firewall
sudo nix-shell -p nmap --run "nmap -p 22 localhost"
```

**Bootstrap fails?**
- Verify secrets exist in Key Vault: `az keyvault secret list --vault-name nix-kids-laptop`
- Check Azure login: `az account show`
- Ensure repo is public on GitHub

## File Structure

```
nix-kids-laptop/
├── bootstrap.sh              # One-command installer
├── flake.nix                 # Nix flake definition
├── configuration.nix         # System configuration
├── home-drew.nix            # Drew's user config
├── home-emily.nix           # Emily's user config
├── home-bella.nix           # Bella's user config
├── hardware-configuration.nix  # Generated during install
├── README.md
├── QUICK-START.md           # This file
├── SETUP-SIMPLIFIED.md      # Detailed setup
├── ONEDRIVE-SETUP.md        # OneDrive details
└── KEYVAULT-SECRETS.md      # Key Vault architecture
```

## Next Steps

1. Follow one-time setup above
2. Test bootstrap on a VM or old laptop first
3. When ready, bootstrap the actual kids' laptop
4. Enjoy fully configured system!

**Total setup time:** ~30 minutes  
**Total restore time:** ~15 minutes
