#!/usr/bin/env bash
# Azure Key Vault Setup Script
# Run this script to populate your Key Vault with all required secrets

set -e

VAULT_NAME="nix-kids-laptop"

echo "========================================"
echo "Azure Key Vault Setup"
echo "========================================"
echo ""

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI not found. Please install it first."
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
    echo "Not logged in to Azure. Logging in now..."
    az login
fi

echo "✓ Logged in to Azure"
echo ""

# Arrays to track progress
declare -a uploaded
declare -a skipped

# Function to upload a secret
upload_secret() {
    local secret_name=$1
    local description=$2
    local instructions=$3
    
    echo "==== $secret_name ===="
    echo "$description"
    if [ -n "$instructions" ]; then
        echo -e "\033[33m$instructions\033[0m"
    fi
    echo ""
    
    # Check if secret exists
    if az keyvault secret show --vault-name "$VAULT_NAME" --name "$secret_name" &> /dev/null; then
        read -p "Secret '$secret_name' already exists. Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping $secret_name"
            echo ""
            skipped+=("$secret_name")
            return 1
        fi
    fi
    
    # Prompt for file path
    read -p "Enter path to file (or 'skip' to skip): " file_path
    
    if [ "$file_path" = "skip" ]; then
        echo "Skipped $secret_name"
        echo ""
        skipped+=("$secret_name")
        return 1
    fi
    
    # Expand tilde
    file_path="${file_path/#\~/$HOME}"
    
    if [ ! -f "$file_path" ]; then
        echo "Error: File not found: $file_path"
        echo ""
        skipped+=("$secret_name")
        return 1
    fi
    
    # Upload to Key Vault
    echo "Uploading to Key Vault..."
    if az keyvault secret set --vault-name "$VAULT_NAME" --name "$secret_name" --file "$file_path" > /dev/null 2>&1; then
        echo "✓ Successfully uploaded $secret_name"
        echo ""
        uploaded+=("$secret_name")
        return 0
    else
        echo "✗ Failed to upload $secret_name"
        echo ""
        skipped+=("$secret_name")
        return 1
    fi
}

# Upload SSH keys
upload_secret \
    "drew-ssh-authorized-keys" \
    "SSH public key(s) for Drew to enable remote access" \
    "Typically ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub"

upload_secret \
    "emily-ssh-authorized-keys" \
    "SSH public key(s) for Emily" \
    "Same as Drew's or different keys if needed"

upload_secret \
    "bella-ssh-authorized-keys" \
    "SSH public key(s) for Bella" \
    "Same as Drew's or different keys if needed"

# Note about rclone
echo ""
echo "NOTE: For rclone configs, you need to run 'rclone config' first!"
echo "See ONEDRIVE-SETUP.md for detailed instructions."
echo ""

# Upload rclone configs
upload_secret \
    "drew-rclone-config" \
    "Drew's OneDrive rclone configuration (drewjamesross@outlook.com)" \
    "After running 'rclone config', file is at: ~/.config/rclone/rclone.conf"

upload_secret \
    "emily-rclone-config" \
    "Emily's OneDrive rclone configuration (emilykamacphee@outlook.com)" \
    "Remember to clear old config first: rm ~/.config/rclone/rclone.conf"

upload_secret \
    "bella-rclone-config" \
    "Bella's OneDrive rclone configuration (isabellaleblanc@outlook.com)" \
    "Remember to clear old config first: rm ~/.config/rclone/rclone.conf"

# Summary
echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""

if [ ${#uploaded[@]} -gt 0 ]; then
    echo "✓ Uploaded (${#uploaded[@]}):"
    for item in "${uploaded[@]}"; do
        echo "  - $item"
    done
    echo ""
fi

if [ ${#skipped[@]} -gt 0 ]; then
    echo "⚠ Skipped (${#skipped[@]}):"
    for item in "${skipped[@]}"; do
        echo "  - $item"
    done
    echo ""
fi

# Verify all secrets
echo "Verifying Key Vault contents..."
echo ""
echo "Current secrets in Key Vault:"
az keyvault secret list --vault-name "$VAULT_NAME" --query "[].name" -o tsv | while read -r secret; do
    echo "  ✓ $secret"
done

echo ""
echo "Next steps:"
echo "1. Ensure all 6 secrets are uploaded (3 SSH keys + 3 rclone configs)"
echo "2. Push your config to GitHub"
echo "3. Run bootstrap script on target NixOS system"
echo ""
echo "To re-run this script: ./setup-keyvault.sh"
