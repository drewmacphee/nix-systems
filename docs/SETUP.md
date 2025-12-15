# Initial Setup Guide

Follow these steps to prepare your configuration before the first install.

## Step 1: Generate Age Key

```bash
# Install age if needed
nix-shell -p age

# Generate your encryption key
age-keygen -o age-key.txt

# View the key
cat age-key.txt
```

You'll see output like:
```
# created: 2024-12-15T15:50:30Z
# public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**Save this file securely!** You need it to decrypt secrets.

## Step 2: Update Configuration Files

1. **Update `.agenix.toml`**:
   - Replace the dummy public key with your actual public key (the line starting with `age1...`)

2. **Update `configuration.nix`**:
   - Adjust timezone, locale, and other settings as needed

4. **Update `flake.nix`**:
   - Line 6: Change NixOS version if desired (24.05 is stable)

## Step 3: Setup Azure Key Vault

```bash
# Login to Azure
az login

# Create resource group (if not already created)
az group create \
  --name kids-laptop-rg \
  --location eastus

# Create Key Vault (if not already created)
# Your vault already exists at: https://nix-kids-laptop.vault.azure.net/
az keyvault create \
  --name nix-kids-laptop \
  --resource-group kids-laptop-rg \
  --location eastus

# Store your age key
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name age-identity \
  --file age-key.txt

# Verify it's stored
az keyvault secret show \
  --vault-name nix-kids-laptop \
  --name age-identity \
  --query value -o tsv
```

## Step 4: Setup OneDrive via rclone

See [ONEDRIVE-SETUP.md](ONEDRIVE-SETUP.md) for detailed instructions on configuring OneDrive for all three users:
- **Drew**: drewjamesross@outlook.com
- **Emily**: emilykamacphee@outlook.com  
- **Bella**: isabellaleblanc@outlook.com

You'll need to run `rclone config` three separate times, once for each Microsoft account, and encrypt each resulting config file with agenix.

## Step 5: Create Encrypted Secrets

```bash
# Install agenix
nix-shell -p agenix

# Create SSH authorized keys file
echo "ssh-ed25519 AAAA...your-public-key... you@admin" > /tmp/authorized_keys

# Encrypt it
agenix -e secrets/kiduser-ssh-authorized-keys.age
# Paste the authorized_keys content, save and exit

# Encrypt admin SSH key (if you want to store private key)
agenix -e secrets/admin-ssh-key.age
# Paste your private SSH key, save and exit

# Encrypt rclone config
agenix -e secrets/rclone-config.age
# Paste the entire rclone.conf content, save and exit
```

## Step 6: Initialize Git Repository

```bash
# Initialize repo
git init
git add .
git commit -m "Initial NixOS kids laptop configuration"

# Create GitHub repo (via web or CLI)
gh repo create nix-kids-laptop --public

# Push to GitHub
git branch -M main
git remote add origin https://github.com/drewmacphee/nix-kids-laptop.git
git push -u origin main
```

## Step 7: Test Bootstrap Script

Before using on the actual laptop, test the URL:

```bash
curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh
```

You should see the script content. If it shows 404, check:
- Repository is public
- You pushed to `main` branch
- File is named exactly `bootstrap.sh`

## Ready to Install!

Now you can use the bootstrap script on a fresh NixOS installation. See README.md for usage instructions.

## Security Notes

- ✅ **SAFE to commit**: `.age` encrypted secret files
- ✅ **SAFE to commit**: Public keys, configs, nix files
- ❌ **NEVER commit**: `age-key.txt`, `*.key`, plain-text secrets
- ❌ **NEVER commit**: `keys.txt` or unencrypted SSH keys

The `.gitignore` is configured to prevent accidental commits of sensitive files.
