#!/usr/bin/env bash
# NixOS Kids Laptop Bootstrap Script
# Usage: curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash

set -euo pipefail

REPO_URL="https://github.com/drewmacphee/nix-kids-laptop"
VAULT_NAME="nix-kids-laptop"
SECRET_NAME="age-identity"
HOSTNAME="kids-laptop"

echo "========================================"
echo "NixOS Kids Laptop Bootstrap"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "ERROR: Please run as root (use sudo)"
   exit 1
fi

echo "Step 1: Installing temporary dependencies..."
nix-shell -p azure-cli git --run "

  echo 'Step 2: Authenticating with Azure...'
  echo 'Please login with your Microsoft account:'
  az login --use-device-code
  
  echo ''
  echo 'Step 3: Fetching secrets from Azure Key Vault...'
  
  # Fetch all secrets
  echo 'Fetching rclone configs...'
  az keyvault secret show --vault-name ${VAULT_NAME} --name drew-rclone-config --query value -o tsv > /tmp/drew-rclone.conf
  az keyvault secret show --vault-name ${VAULT_NAME} --name emily-rclone-config --query value -o tsv > /tmp/emily-rclone.conf
  az keyvault secret show --vault-name ${VAULT_NAME} --name bella-rclone-config --query value -o tsv > /tmp/bella-rclone.conf
  
  echo 'Fetching SSH authorized keys...'
  az keyvault secret show --vault-name ${VAULT_NAME} --name drew-ssh-authorized-keys --query value -o tsv > /tmp/drew-ssh-keys
  az keyvault secret show --vault-name ${VAULT_NAME} --name emily-ssh-authorized-keys --query value -o tsv > /tmp/emily-ssh-keys
  az keyvault secret show --vault-name ${VAULT_NAME} --name bella-ssh-authorized-keys --query value -o tsv > /tmp/bella-ssh-keys
  
  # Verify critical files
  if [ ! -s /tmp/drew-rclone.conf ]; then
    echo 'ERROR: Failed to fetch drew-rclone-config from Key Vault'
    exit 1
  fi
  
  echo 'Successfully retrieved all secrets!'
"

echo ""
echo "Step 4: Cloning configuration repository..."
if [ -d "/etc/nixos/.git" ]; then
  echo "Config already exists, pulling latest..."
  cd /etc/nixos
  git pull
else
  # Backup existing config
  if [ -d "/etc/nixos" ]; then
    mv /etc/nixos /etc/nixos.backup.$(date +%Y%m%d-%H%M%S)
  fi
  git clone "${REPO_URL}" /etc/nixos
fi

echo ""
echo "Step 5: Installing secrets for NixOS configuration..."
mkdir -p /tmp/nixos-secrets

# Copy rclone configs
cp /tmp/drew-rclone.conf /tmp/nixos-secrets/drew-rclone.conf
cp /tmp/emily-rclone.conf /tmp/nixos-secrets/emily-rclone.conf
cp /tmp/bella-rclone.conf /tmp/nixos-secrets/bella-rclone.conf

# Copy SSH keys
cp /tmp/drew-ssh-keys /tmp/nixos-secrets/drew-ssh-authorized-keys
cp /tmp/emily-ssh-keys /tmp/nixos-secrets/emily-ssh-authorized-keys
cp /tmp/bella-ssh-keys /tmp/nixos-secrets/bella-ssh-authorized-keys

# Set permissions
chmod 600 /tmp/nixos-secrets/*-rclone.conf
chmod 644 /tmp/nixos-secrets/*-ssh-authorized-keys

# Clean up temp files from Key Vault
rm -f /tmp/drew-rclone.conf /tmp/emily-rclone.conf /tmp/bella-rclone.conf
rm -f /tmp/drew-ssh-keys /tmp/emily-ssh-keys /tmp/bella-ssh-keys

echo ""
echo "Step 6: Applying NixOS configuration..."
echo "This will take several minutes (downloading packages)..."
cd /etc/nixos
nixos-rebuild switch --flake ".#${HOSTNAME}"

echo ""
echo "========================================"
echo "Bootstrap Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. OneDrive sync will start automatically on first login"
echo "3. You can remote in via VS Code once the system is up"
echo ""
