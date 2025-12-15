# Azure Key Vault Setup Guide

Follow these steps to populate your Key Vault with all required secrets.

## Prerequisites

- Azure CLI installed and working
- Access to Key Vault: `nix-kids-laptop.vault.azure.net`
- SSH keys generated (if not, run: `ssh-keygen -t ed25519`)
- rclone configured for each OneDrive account (see ONEDRIVE-SETUP.md)

## Option 1: Interactive Script (Recommended)

### On Windows:
```powershell
cd C:\git\nix-kids-laptop
.\setup-keyvault.ps1
```

### On Linux/Mac:
```bash
cd /path/to/nix-kids-laptop
chmod +x setup-keyvault.sh
./setup-keyvault.sh
```

The script will:
1. Check if you're logged into Azure
2. Prompt for each secret file
3. Upload to Key Vault
4. Verify all secrets are stored

## Option 2: Manual Setup

If the script doesn't work, manually upload each secret:

### 1. Login to Azure
```bash
az login
```

### 2. Upload SSH Keys

```bash
# For Drew (repeat for emily and bella)
cat ~/.ssh/id_ed25519.pub > /tmp/authorized_keys
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name drew-ssh-authorized-keys \
  --file /tmp/authorized_keys

az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name emily-ssh-authorized-keys \
  --file /tmp/authorized_keys

az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name bella-ssh-authorized-keys \
  --file /tmp/authorized_keys

rm /tmp/authorized_keys
```

### 3. Configure and Upload rclone for Drew

```bash
# Configure rclone
rclone config

# Follow prompts:
# - name: onedrive
# - storage: onedrive (usually option 31)
# - Leave client_id and client_secret blank
# - region: 1 (Global)
# - Use auto config: Yes
# - Login with: drewjamesross@outlook.com
# - Account type: 1 (OneDrive Personal)

# Upload to Key Vault
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name drew-rclone-config \
  --file ~/.config/rclone/rclone.conf
```

### 4. Configure and Upload rclone for Emily

```bash
# Clear previous config
rm ~/.config/rclone/rclone.conf

# Configure for Emily
rclone config
# Login with: emilykamacphee@outlook.com

# Upload to Key Vault
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name emily-rclone-config \
  --file ~/.config/rclone/rclone.conf
```

### 5. Configure and Upload rclone for Bella

```bash
# Clear previous config
rm ~/.config/rclone/rclone.conf

# Configure for Bella
rclone config
# Login with: isabellaleblanc@outlook.com

# Upload to Key Vault
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name bella-rclone-config \
  --file ~/.config/rclone/rclone.conf
```

### 6. Verify All Secrets

```bash
# List all secrets
az keyvault secret list --vault-name nix-kids-laptop --query "[].name" -o table

# Should show:
# drew-ssh-authorized-keys
# emily-ssh-authorized-keys
# bella-ssh-authorized-keys
# drew-rclone-config
# emily-rclone-config
# bella-rclone-config
```

### 7. Test Retrieval

```bash
# Test fetching one secret
az keyvault secret show \
  --vault-name nix-kids-laptop \
  --name drew-rclone-config \
  --query value -o tsv
```

If you see the rclone config content, everything is working!

## Common Issues

**"Secret not found" error:**
- Make sure you're using the correct vault name: `nix-kids-laptop`
- Verify you have access: `az keyvault secret list --vault-name nix-kids-laptop`

**"Access denied" error:**
- Check Key Vault access policies in Azure Portal
- Ensure your account has "Get" and "Set" permissions for secrets

**"rclone.conf not found":**
- On Linux/Mac: `~/.config/rclone/rclone.conf`
- On Windows: `%APPDATA%\rclone\rclone.conf`
- Make sure you ran `rclone config` first

**OneDrive OAuth token expired:**
- Re-run `rclone config` to refresh the token
- Upload the new config to Key Vault
- On the laptop: `sudo nixos-rebuild switch --flake /etc/nixos#kids-laptop`

## What Each Secret Contains

**SSH Keys (`*-ssh-authorized-keys`):**
- Your SSH public key(s) in authorized_keys format
- Example: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxx... user@host`
- Enables remote SSH access after bootstrap

**rclone Configs (`*-rclone-config`):**
- Complete rclone configuration for OneDrive
- Includes OAuth2 tokens, refresh tokens, drive IDs
- Format: INI-style config file
- Example:
  ```
  [onedrive]
  type = onedrive
  token = {"access_token":"xxx"...}
  drive_id = xxx
  drive_type = personal
  ```

## Security Notes

✅ **Safe in Key Vault:**
- All secrets encrypted at rest by Azure
- Access logged and auditable
- RBAC controls who can access
- Backed up by Microsoft

⚠️ **Never commit to git:**
- Don't put these secrets in your repo
- `.gitignore` already excludes `secrets/` directory
- Bootstrap script fetches from Key Vault at runtime

🔒 **Rotation:**
- SSH keys: Rarely need rotation unless compromised
- rclone tokens: OAuth tokens auto-refresh, but full config lasts ~90 days
- When updating: Just upload new version to Key Vault, no git commits needed

## Next Steps

Once all 6 secrets are in Key Vault:

1. ✓ Verify with: `az keyvault secret list --vault-name nix-kids-laptop`
2. ✓ Push your config to GitHub (secrets not included)
3. ✓ Test bootstrap on a VM or spare machine
4. ✓ Bootstrap the actual kids' laptop

**You're ready to go!** 🚀
