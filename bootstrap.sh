#!/usr/bin/env bash
# NixOS Kids Laptop Bootstrap Script
# Usage: curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash

set -euo pipefail

REPO_URL="https://github.com/drewmacphee/nix-kids-laptop"
VAULT_NAME="bazztop"
SECRET_NAME="age-identity"
HOSTNAME="bazztop"

# Error handler
trap 'echo "ERROR: Bootstrap failed at line $LINENO. Check output above for details." >&2; exit 1' ERR

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "ERROR: Please run as root (use sudo)"
   exit 1
fi

echo "Step 1: Installing temporary dependencies..."
nix-shell -p azure-cli git --run bash <<'AZURE_LOGIN'
set -euo pipefail

echo 'Step 2: Authenticating with Azure...'
echo 'Please login with your Microsoft account:'

# Azure login with retry
max_attempts=3
attempt=1

while [ $attempt -le $max_attempts ]; do
  if az login --use-device-code; then
    echo "✓ Azure login successful"
    break
  fi
  
  if [ $attempt -lt $max_attempts ]; then
    echo "Attempt $attempt/$max_attempts failed, retrying..."
    sleep 5
  else
    echo 'ERROR: Azure login failed after multiple attempts'
    exit 1
  fi
  attempt=$((attempt + 1))
done
  
echo ''
echo 'Step 3: Fetching secrets from Azure Key Vault...'

# Fetch all secrets with retry logic
echo 'Fetching rclone configs...'
az keyvault secret show --vault-name ${VAULT_NAME} --name drew-rclone-config --query value -o tsv > /tmp/drew-rclone.conf || exit 1
az keyvault secret show --vault-name ${VAULT_NAME} --name emily-rclone-config --query value -o tsv > /tmp/emily-rclone.conf || exit 1
az keyvault secret show --vault-name ${VAULT_NAME} --name bella-rclone-config --query value -o tsv > /tmp/bella-rclone.conf || exit 1

echo 'Fetching SSH authorized keys...'
az keyvault secret show --vault-name ${VAULT_NAME} --name drew-ssh-authorized-keys --query value -o tsv > /tmp/drew-ssh-keys || exit 1
az keyvault secret show --vault-name ${VAULT_NAME} --name emily-ssh-authorized-keys --query value -o tsv > /tmp/emily-ssh-keys || exit 1
az keyvault secret show --vault-name ${VAULT_NAME} --name bella-ssh-authorized-keys --query value -o tsv > /tmp/bella-ssh-keys || exit 1

echo 'Fetching user passwords...'
az keyvault secret show --vault-name ${VAULT_NAME} --name drew-password --query value -o tsv > /tmp/drew-password || exit 1
az keyvault secret show --vault-name ${VAULT_NAME} --name emily-password --query value -o tsv > /tmp/emily-password || exit 1
az keyvault secret show --vault-name ${VAULT_NAME} --name bella-password --query value -o tsv > /tmp/bella-password || exit 1

echo 'Fetching WiFi credentials...'
az keyvault secret show --vault-name ${VAULT_NAME} --name wifi-ssid --query value -o tsv > /tmp/wifi-ssid || exit 1
az keyvault secret show --vault-name ${VAULT_NAME} --name wifi-password --query value -o tsv > /tmp/wifi-password || exit 1

echo ''
echo '✓ All secrets retrieved successfully!'
AZURE_LOGIN

echo ""
echo "Step 4: Cloning configuration repository..."

# Preserve the real hardware-configuration.nix
if [ -f "/etc/nixos/hardware-configuration.nix" ]; then
  echo "Backing up real hardware-configuration.nix..."
  cp /etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix.real || {
    echo "ERROR: Failed to backup hardware-configuration.nix"
    exit 1
  }
else
  echo "WARNING: No existing hardware-configuration.nix found"
  echo "This is expected on first install, but ensure one exists after nixos-generate-config"
fi

if [ -d "/etc/nixos/.git" ]; then
  echo "Config already exists, pulling latest..."
  cd /etc/nixos
  if ! retry_command git pull; then
    echo "ERROR: Failed to pull latest configuration"
    exit 1
  fi
else
  # Backup existing config
  if [ -d "/etc/nixos" ]; then
    backup_dir="/etc/nixos.backup.$(date +%Y%m%d-%H%M%S)"
    echo "Backing up existing config to $backup_dir..."
    mv /etc/nixos "$backup_dir" || {
      echo "ERROR: Failed to backup existing /etc/nixos"
      exit 1
    }
  fi
  
  echo "Cloning configuration repository..."
  if ! retry_command git clone "${REPO_URL}" /etc/nixos; then
    echo "ERROR: Failed to clone configuration repository"
    exit 1
  fi
fi

# Restore the real hardware-configuration.nix
if [ -f "/tmp/hardware-configuration.nix.real" ]; then
  echo "Restoring real hardware-configuration.nix..."
  cp /tmp/hardware-configuration.nix.real /etc/nixos/hardware-configuration.nix || {
    echo "ERROR: Failed to restore hardware-configuration.nix"
    exit 1
  }
  rm /tmp/hardware-configuration.nix.real
  echo "✓ Hardware configuration preserved"
else
  echo "WARNING: No hardware-configuration.nix to restore!"
  echo "If this is a fresh install, ensure hardware-configuration.nix exists"
  echo "Run: nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix"
  
  # Check if one exists now (might have been in repo)
  if [ ! -f "/etc/nixos/hardware-configuration.nix" ]; then
    echo "ERROR: No hardware-configuration.nix found. Cannot proceed."
    echo "Generate it with: nixos-generate-config"
    exit 1
  fi
fi

echo ""
echo "Step 5: Installing secrets for NixOS configuration..."

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
echo "Step 6: Applying NixOS configuration..."
echo "This will take several minutes (downloading packages)..."

cd /etc/nixos || {
  echo "ERROR: Cannot change to /etc/nixos directory"
  exit 1
}

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

if ! nixos-rebuild switch --flake ".#nix-kids-laptop"; then
  echo ""
  echo "ERROR: nixos-rebuild failed!"
  echo "Check the error messages above for details."
  echo "Secrets are preserved in /tmp/nixos-secrets and /tmp/nixos-passwords"
  echo "You can retry with: cd /etc/nixos && nixos-rebuild switch --flake '.#nix-kids-laptop'"
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
