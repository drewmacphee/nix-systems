#!/usr/bin/env bash
# NixOS Kids Laptop Bootstrap Script
# Usage: curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash

set -euo pipefail

REPO_URL="https://github.com/drewmacphee/nix-kids-laptop"
VAULT_NAME="nix-kids-laptop"
SECRET_NAME="age-identity"
TENANT_ID="6e2722da-5af4-4c0f-878a-42db4d068c86"

# Error handler
trap 'echo "ERROR: Bootstrap failed at line $LINENO. Check output above for details." >&2; exit 1' ERR

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root (use sudo)"
  exit 1
fi

# Validation function
validate_secret() {
  local file=$1
  local name=$2
  
  if [ ! -f "$file" ]; then
    echo "ERROR: $name file not found at $file"
    return 1
  fi
  
  if [ ! -s "$file" ]; then
    echo "ERROR: $name is empty"
    return 1
  fi
  
  if [ $(wc -c < "$file") -lt 10 ]; then
    echo "ERROR: $name seems invalid (too short: $(wc -c < "$file") bytes)"
    return 1
  fi
  
  echo "✓ $name validated"
  return 0
}

# Retry function for network operations
retry_command() {
  local max_attempts=3
  local attempt=1
  local delay=5
  
  while [ $attempt -le $max_attempts ]; do
    if "$@"; then
      return 0
    fi
    
    if [ $attempt -lt $max_attempts ]; then
      echo "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
      sleep $delay
      delay=$((delay * 2))  # Exponential backoff
    fi
    attempt=$((attempt + 1))
  done
  
  echo "ERROR: Command failed after $max_attempts attempts: $*"
  return 1
}

echo "========================================"
echo "NixOS Kids Laptop Bootstrap"
echo "========================================"
echo ""

# Prompt for hostname (optional - defaults handled by hostname.nix)
echo "Enter hostname for this machine (press Enter for auto-generated default):"
read -r HOSTNAME </dev/tty

if [ -n "$HOSTNAME" ]; then
  echo "✓ Using hostname: $HOSTNAME"
else
  echo "✓ Using auto-generated hostname (will be set during NixOS build)"
  HOSTNAME=""  # Empty means use the default from hostname.nix
fi
echo ""

echo "Step 1: Installing temporary dependencies..."
nix-shell -p azure-cli git --run bash <<'AZURE_LOGIN'
set -euo pipefail

echo 'Step 2: Authenticating with Azure...'
echo 'You will need to:'
echo '  1. Visit https://microsoft.com/devicelogin'
echo '  2. Enter the code shown below'
echo '  3. Complete MFA authentication'
echo ''

# Use device code flow - more reliable and works with MFA
if ! az login --tenant 6e2722da-5af4-4c0f-878a-42db4d068c86 --use-device-code --allow-no-subscriptions; then
  echo ''
  echo 'ERROR: Azure login failed. Please ensure:'
  echo '  - You completed the device code authentication'
  echo '  - You can complete MFA authentication'
  echo '  - You have access to tenant 6e2722da-5af4-4c0f-878a-42db4d068c86'
  exit 1
fi

echo "✓ Azure login successful"
  
echo ''
echo 'Step 4: Fetching secrets from Azure Key Vault...'

VAULT_NAME="nix-kids-laptop"

# Fetch all secrets with retry logic
echo 'Fetching rclone configs...'
az keyvault secret show --vault-name $VAULT_NAME --name drew-rclone-config --query value -o tsv > /tmp/drew-rclone.conf || exit 1
az keyvault secret show --vault-name $VAULT_NAME --name emily-rclone-config --query value -o tsv > /tmp/emily-rclone.conf || exit 1
az keyvault secret show --vault-name $VAULT_NAME --name bella-rclone-config --query value -o tsv > /tmp/bella-rclone.conf || exit 1

echo 'Fetching SSH authorized keys...'
az keyvault secret show --vault-name $VAULT_NAME --name drew-ssh-authorized-keys --query value -o tsv > /tmp/drew-ssh-keys || exit 1
az keyvault secret show --vault-name $VAULT_NAME --name emily-ssh-authorized-keys --query value -o tsv > /tmp/emily-ssh-keys || exit 1
az keyvault secret show --vault-name $VAULT_NAME --name bella-ssh-authorized-keys --query value -o tsv > /tmp/bella-ssh-keys || exit 1

echo 'Fetching user passwords...'
az keyvault secret show --vault-name $VAULT_NAME --name drew-password --query value -o tsv > /tmp/drew-password || exit 1
az keyvault secret show --vault-name $VAULT_NAME --name emily-password --query value -o tsv > /tmp/emily-password || exit 1
az keyvault secret show --vault-name $VAULT_NAME --name bella-password --query value -o tsv > /tmp/bella-password || exit 1

echo 'Fetching WiFi credentials...'
az keyvault secret show --vault-name $VAULT_NAME --name wifi-ssid --query value -o tsv > /tmp/wifi-ssid || exit 1
az keyvault secret show --vault-name $VAULT_NAME --name wifi-password --query value -o tsv > /tmp/wifi-password || exit 1

echo ''
echo '✓ All secrets retrieved successfully!'
AZURE_LOGIN

echo ""
echo "Step 2: Cloning configuration repository..."

# Clean slate approach - backup existing config and preserve hardware-configuration.nix
BACKUP_DIR=""
if [ -d "/etc/nixos" ] && [ "$(ls -A /etc/nixos)" ]; then
  echo "Existing /etc/nixos found. Creating backup..."
  BACKUP_DIR="/etc/nixos.backup.$(date +%Y%m%d-%H%M%S)"
  mv /etc/nixos "$BACKUP_DIR"
  echo "✓ Backed up to $BACKUP_DIR"
fi

# Ensure /etc/nixos exists and is empty
mkdir -p /etc/nixos
cd /etc/nixos

echo "Cloning fresh configuration..."
if ! retry_command git clone "$REPO_URL" .; then
  echo "ERROR: Failed to clone configuration repository"
  exit 1
fi

echo "✓ Repository cloned successfully"

# Restore hardware-configuration.nix from backup or generate new one
if [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/hardware-configuration.nix" ]; then
  echo "Restoring hardware-configuration.nix from backup..."
  cp "$BACKUP_DIR/hardware-configuration.nix" /etc/nixos/hardware-configuration.nix
  echo "✓ Hardware configuration restored from backup"
else
  echo "Generating new hardware-configuration.nix..."
  nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
  echo "✓ Hardware configuration generated"
fi

echo ""
echo "Step 3: Installing secrets for NixOS configuration..."

# Create secret directories
mkdir -p /tmp/nixos-secrets || {
  echo "ERROR: Failed to create /tmp/nixos-secrets"
  exit 1
}
mkdir -p /tmp/nixos-passwords || {
  echo "ERROR: Failed to create /tmp/nixos-passwords"
  exit 1
}

# Copy rclone configs
echo "Installing rclone configs..."
cp /tmp/drew-rclone.conf /tmp/nixos-secrets/drew-rclone.conf || exit 1
cp /tmp/emily-rclone.conf /tmp/nixos-secrets/emily-rclone.conf || exit 1
cp /tmp/bella-rclone.conf /tmp/nixos-secrets/bella-rclone.conf || exit 1

# Copy SSH keys
echo "Installing SSH keys..."
cp /tmp/drew-ssh-keys /tmp/nixos-secrets/drew-ssh-authorized-keys || exit 1
cp /tmp/emily-ssh-keys /tmp/nixos-secrets/emily-ssh-authorized-keys || exit 1
cp /tmp/bella-ssh-keys /tmp/nixos-secrets/bella-ssh-authorized-keys || exit 1

# Save passwords for later (after users are created)
echo "Saving passwords..."
cp /tmp/drew-password /tmp/nixos-passwords/ || exit 1
cp /tmp/emily-password /tmp/nixos-passwords/ || exit 1
cp /tmp/bella-password /tmp/nixos-passwords/ || exit 1

# Create WiFi environment file
echo "Creating WiFi configuration..."
echo "WIFI_SSID=$(cat /tmp/wifi-ssid)" > /tmp/nixos-secrets/wifi-env || exit 1
echo "WIFI_PASSWORD=$(cat /tmp/wifi-password)" >> /tmp/nixos-secrets/wifi-env || exit 1
chmod 600 /tmp/nixos-secrets/wifi-env || exit 1

# Set permissions
echo "Setting file permissions..."
chmod 600 /tmp/nixos-secrets/*-rclone.conf || exit 1
chmod 644 /tmp/nixos-secrets/*-ssh-authorized-keys || exit 1
chmod 600 /tmp/nixos-passwords/* || exit 1

# Verify secrets directory
echo "Verifying secrets installation..."
[ -f "/tmp/nixos-secrets/drew-rclone.conf" ] || { echo "ERROR: drew-rclone.conf missing"; exit 1; }
[ -f "/tmp/nixos-secrets/drew-ssh-authorized-keys" ] || { echo "ERROR: drew SSH keys missing"; exit 1; }
[ -f "/tmp/nixos-secrets/wifi-env" ] || { echo "ERROR: wifi-env missing"; exit 1; }
echo "✓ All secrets installed to /tmp/nixos-secrets"

# Clean up temp files from Key Vault
echo "Cleaning up temporary files..."
rm -f /tmp/drew-rclone.conf /tmp/emily-rclone.conf /tmp/bella-rclone.conf
rm -f /tmp/drew-ssh-keys /tmp/emily-ssh-keys /tmp/bella-ssh-keys
rm -f /tmp/drew-password /tmp/emily-password /tmp/bella-password
rm -f /tmp/wifi-ssid /tmp/wifi-password

echo ""
echo "Step 4: Creating hostname configuration..."

cd /etc/nixos || {
  echo "ERROR: Cannot change to /etc/nixos directory"
  exit 1
}

# Create hostname.nix module only if hostname was provided
if [ -n "$HOSTNAME" ]; then
  cat > modules/hostname.nix << EOF
# This file is auto-generated by bootstrap.sh
# Generated on: $(date)
{ config, pkgs, ... }:

{
  networking.hostName = "$HOSTNAME";
}
EOF

  [ $? -eq 0 ] || {
    echo "ERROR: Failed to create hostname.nix"
    exit 1
  }

  echo "✓ Hostname configured: $HOSTNAME"
else
  # If hostname.nix doesn't exist, create it with the default
  if [ ! -f modules/hostname.nix ]; then
    cat > modules/hostname.nix << 'EOF'
# This file is auto-generated by bootstrap.sh
{ config, lib, ... }:

{
  networking.hostName = lib.mkDefault "nix-${builtins.substring 0 4 (builtins.hashString "sha256" config.networking.hostId)}";
}
EOF
    echo "✓ Hostname will be auto-generated during build"
  else
    echo "✓ Using existing hostname.nix configuration"
  fi
fi

echo ""
echo "Step 5: Verifying hardware configuration..."
# This should have been restored/generated in Step 2
if [ ! -f hardware-configuration.nix ]; then
  echo "ERROR: No hardware-configuration.nix found!"
  exit 1
fi
echo "✓ Hardware configuration ready"

echo ""
echo "Step 6: Applying NixOS configuration..."
echo "This will take several minutes (downloading packages)..."

# Copy secrets to /etc/nixos for the build
echo "Copying secrets for NixOS build..."
mkdir -p /etc/nixos/secrets || {
  echo "ERROR: Failed to create /etc/nixos/secrets"
  exit 1
}
cp -r /tmp/nixos-secrets/* /etc/nixos/secrets/ || {
  echo "ERROR: Failed to copy secrets to /etc/nixos/secrets"
  exit 1
}

echo "Building NixOS configuration..."
echo "This may take 10-30 minutes depending on internet speed..."

if ! sudo nixos-rebuild switch --flake .#kids-laptop; then
  echo ""
  echo "ERROR: nixos-rebuild failed!"
  echo "Check the error messages above for details."
  echo "Secrets are preserved in /tmp/nixos-secrets and /tmp/nixos-passwords"
  echo "You can retry with: cd /etc/nixos && sudo nixos-rebuild switch --flake .#kids-laptop"
  exit 1
fi

echo "✓ NixOS configuration applied successfully"

echo ""
echo "Step 7: Setting user passwords..."

# Verify users were created
for user in drew emily bella; do
  if ! id "$user" &>/dev/null; then
    echo "ERROR: User $user was not created by nixos-rebuild"
    exit 1
  fi
done
echo "✓ All users exist"

# Now that users exist, set their passwords
echo "Setting passwords..."
if ! echo "drew:$(cat /tmp/nixos-passwords/drew-password)" | chpasswd; then
  echo "ERROR: Failed to set Drew's password"
  exit 1
fi

if ! echo "emily:$(cat /tmp/nixos-passwords/emily-password)" | chpasswd; then
  echo "ERROR: Failed to set Emily's password"
  exit 1
fi

if ! echo "bella:$(cat /tmp/nixos-passwords/bella-password)" | chpasswd; then
  echo "ERROR: Failed to set Bella's password"
  exit 1
fi

echo "✓ Passwords set for all users"

# Clean up password files securely
echo "Cleaning up sensitive files..."
shred -u /tmp/nixos-passwords/* 2>/dev/null || rm -f /tmp/nixos-passwords/*
rmdir /tmp/nixos-passwords 2>/dev/null || true

echo ""
echo "========================================"
echo "Bootstrap Complete!"
echo "========================================"
echo ""
echo "System configured with:"
echo "  - 3 user accounts (Drew, Emily, Bella)"
echo "  - Passwords set from Key Vault"
echo "  - SSH access configured"
echo "  - OneDrive rclone configs installed"
echo "  - Gaming software (Steam, Minecraft)"
echo "  - Development tools"
echo ""
echo "User passwords retrieved from Key Vault."
echo "You can view them anytime with:"
echo "  az keyvault secret show --vault-name nix-kids-laptop --name drew-password --query value -o tsv"
echo "  az keyvault secret show --vault-name nix-kids-laptop --name emily-password --query value -o tsv"
echo "  az keyvault secret show --vault-name nix-kids-laptop --name bella-password --query value -o tsv"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. OneDrive sync will start automatically on first login"
echo "3. You can remote in via VS Code once the system is up"
echo ""
