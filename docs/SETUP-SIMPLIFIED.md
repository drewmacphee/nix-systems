# Simplified Setup Guide (Key Vault Only)

This is the new simplified setup process using Azure Key Vault for all secrets.

## Prerequisites

- Azure account with access to Key Vault: `https://nix-kids-laptop.vault.azure.net/`
- Azure CLI installed locally
- rclone installed locally for initial OneDrive setup

## Step 1: Configure OneDrive for All Users

Follow [ONEDRIVE-SETUP.md](ONEDRIVE-SETUP.md) to configure rclone for each user's OneDrive account:
- Drew: drewjamesross@outlook.com
- Emily: emilykamacphee@outlook.com
- Bella: isabellaleblanc@outlook.com

## Step 2: Store OneDrive Configs in Key Vault

After configuring each user's OneDrive with rclone:

```bash
# Login to Azure
az login

# Store Drew's rclone config
rclone config  # Configure for drewjamesross@outlook.com
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name drew-rclone-config \
  --file ~/.config/rclone/rclone.conf

# Store Emily's rclone config
rm ~/.config/rclone/rclone.conf
rclone config  # Configure for emilykamacphee@outlook.com
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name emily-rclone-config \
  --file ~/.config/rclone/rclone.conf

# Store Bella's rclone config
rm ~/.config/rclone/rclone.conf
rclone config  # Configure for isabellaleblanc@outlook.com
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name bella-rclone-config \
  --file ~/.config/rclone/rclone.conf
```

## Step 3: Store SSH Keys in Key Vault

```bash
# Create SSH authorized keys file (your public key for remote access)
cat ~/.ssh/id_ed25519.pub > /tmp/authorized_keys
# Or if you use RSA: cat ~/.ssh/id_rsa.pub > /tmp/authorized_keys

# Store for all users (same keys for simplicity, or use different keys per user)
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

# Clean up
rm /tmp/authorized_keys
```

## Step 4: Verify Secrets in Key Vault

```bash
# List all secrets
az keyvault secret list --vault-name nix-kids-laptop --query "[].name" -o table

# Should show:
# - drew-rclone-config
# - emily-rclone-config
# - bella-rclone-config
# - drew-ssh-authorized-keys
# - emily-ssh-authorized-keys
# - bella-ssh-authorized-keys

# Test retrieving one
az keyvault secret show \
  --vault-name nix-kids-laptop \
  --name drew-rclone-config \
  --query value -o tsv
```

## Step 5: Customize Configuration (Optional)

Update `configuration.nix` if needed:
- Timezone (line 18): `time.timeZone = "America/New_York";`
- Locale (line 19): `i18n.defaultLocale = "en_US.UTF-8";`
- Add more system packages

## Step 6: Push to GitHub

```bash
cd /path/to/nix-kids-laptop

# Initialize git if not already done
git init
git add .
git commit -m "Initial NixOS kids laptop configuration"

# Create repo and push
gh repo create nix-kids-laptop --public --source=. --remote=origin --push

# Or manually:
git remote add origin https://github.com/drewmacphee/nix-kids-laptop.git
git branch -M main
git push -u origin main
```

## Step 7: Test Bootstrap Script

Before using on the actual laptop, verify the script is accessible:

```bash
curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh
```

## Ready to Install!

Now on a freshly installed NixOS system, just run:

```bash
curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash
```

That's it! The script will:
1. Prompt for Azure login
2. Fetch all secrets from Key Vault
3. Clone your GitHub repo
4. Apply the complete configuration
5. Setup OneDrive for all users

## Updating Secrets Later

To update any secret (e.g., when OneDrive OAuth token expires):

```bash
# Reconfigure rclone
rclone config

# Update in Key Vault
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name drew-rclone-config \
  --file ~/.config/rclone/rclone.conf

# On the laptop, re-run configuration
ssh drew@kids-laptop
sudo nixos-rebuild switch --flake /etc/nixos#kids-laptop
```

No git commits needed for secret updates!

## Benefits of This Approach

✅ **No local encryption** - No agenix, no age keys to manage  
✅ **No secrets in git** - Even encrypted secrets aren't committed  
✅ **Easy updates** - Change secrets in Key Vault, rebuild  
✅ **Centralized** - All secrets in one place  
✅ **Auditable** - Azure tracks all secret access  
✅ **Simple** - Just configure rclone once, store in vault, done  
