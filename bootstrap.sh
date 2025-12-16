#!/usr/bin/env bash
# NixOS Kids Laptop Bootstrap Script
# Usage: curl -L https://raw.githubusercontent.com/drewmacphee/nix-systems/main/bootstrap.sh | sudo bash

set -euo pipefail

REPO_URL="https://github.com/drewmacphee/nix-systems"
VAULT_NAME="nix-systems-kv"
TENANT_ID="6e2722da-5af4-4c0f-878a-42db4d068c86"

# Where encrypted *.cred files are stored (systemd "credstore")
CREDS_DIR="/etc/credstore.encrypted"

# Host secret used by systemd-creds when encrypting/decrypting with the default "host" key
HOST_SECRET_FILE="/var/lib/systemd/credential.secret"

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

# Machine selection
echo "Select a machine:"
echo "  1) bazztop"
echo "  2) New machine (you'll enter a hostname)"
echo ""
read -p "Enter selection [1-2]: " -r MACHINE_CHOICE </dev/tty

case "$MACHINE_CHOICE" in
  1)
    HOSTNAME="bazztop"
    echo "✓ Selected: bazztop"
    ;;
  2)
    echo ""
    echo "Enter hostname for new machine (lowercase, no spaces):"
    read -r HOSTNAME </dev/tty
    if [ -z "$HOSTNAME" ]; then
      echo "ERROR: hostname cannot be empty"
      exit 1
    fi
    # Validate hostname format
    if ! echo "$HOSTNAME" | grep -qE '^[a-z0-9-]+$'; then
      echo "ERROR: hostname must contain only lowercase letters, numbers, and hyphens"
      exit 1
    fi
    echo "✓ Using hostname: $HOSTNAME"
    echo ""
    echo "NOTE: You will need to add this machine to flake.nix later:"
    echo "  hosts/$HOSTNAME/default.nix"
    echo "  hosts/$HOSTNAME/hardware-configuration.nix"
    ;;
  *)
    echo "ERROR: Invalid selection"
    exit 1
    ;;
esac
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

# Copy hardware-configuration.nix to the correct host directory
if [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/hardware-configuration.nix" ]; then
  echo "Restoring hardware-configuration.nix from backup..."
  cp "$BACKUP_DIR/hardware-configuration.nix" /etc/nixos/hosts/$HOSTNAME/hardware-configuration.nix
  echo "✓ Hardware configuration restored from backup"
else
  echo "Generating new hardware-configuration.nix..."
  nixos-generate-config --show-hardware-config > /etc/nixos/hosts/$HOSTNAME/hardware-configuration.nix
  echo "✓ Hardware configuration generated"
fi

echo ""
echo "Step 3: Encrypting and storing secrets with systemd-creds..."

encrypt_credential() {
  local input="$2"
  local output="$3"
  # systemd-creds requires the embedded name to match the filename when decrypting
  local name=$(basename "$output")

  # Prefer TPM/hardware binding if available, but fall back to host key for reliability.
  if systemd-creds encrypt --with-key=auto --name="$name" "$input" "$output"; then
    return 0
  fi
  echo "WARN: systemd-creds --with-key=auto failed; retrying with --with-key=host" >&2
  systemd-creds encrypt --with-key=host --name="$name" "$input" "$output"
}

# Ensure the host secret is a file (a previous buggy run may have created it as a directory)
if [ -d "$HOST_SECRET_FILE" ]; then
  if [ -z "$(ls -A "$HOST_SECRET_FILE" 2>/dev/null || true)" ]; then
    rmdir "$HOST_SECRET_FILE"
  else
    echo "ERROR: $HOST_SECRET_FILE is a directory (not empty); cannot continue."
    echo "Fix by moving it aside, then re-run the bootstrap."
    exit 1
  fi
fi

echo "Ensuring systemd credential host secret exists..."
if [ -f "$HOST_SECRET_FILE" ]; then
  # systemd-creds refuses to use an existing host secret if permissions are too permissive.
  chown root:root "$HOST_SECRET_FILE"
  chmod 0400 "$HOST_SECRET_FILE"
fi
if ! systemd-creds setup; then
  echo "ERROR: systemd-creds setup failed; cannot initialize host credential secret."
  exit 1
fi

if [ ! -f "$HOST_SECRET_FILE" ]; then
  echo "ERROR: Expected host secret at $HOST_SECRET_FILE after setup, but it was not found."
  exit 1
fi

# Ensure credential directory exists
mkdir -p "$CREDS_DIR"
chmod 700 "$CREDS_DIR"

# Encrypt and store each secret using systemd-creds
echo "Encrypting rclone configs..."
encrypt_credential drew-rclone /tmp/drew-rclone.conf "$CREDS_DIR/drew-rclone.cred" || exit 1
encrypt_credential emily-rclone /tmp/emily-rclone.conf "$CREDS_DIR/emily-rclone.cred" || exit 1
encrypt_credential bella-rclone /tmp/bella-rclone.conf "$CREDS_DIR/bella-rclone.cred" || exit 1

echo "Encrypting SSH keys..."
encrypt_credential drew-ssh-authorized-keys /tmp/drew-ssh-keys "$CREDS_DIR/drew-ssh-authorized-keys.cred" || exit 1
encrypt_credential emily-ssh-authorized-keys /tmp/emily-ssh-keys "$CREDS_DIR/emily-ssh-authorized-keys.cred" || exit 1
encrypt_credential bella-ssh-authorized-keys /tmp/bella-ssh-keys "$CREDS_DIR/bella-ssh-authorized-keys.cred" || exit 1

echo "Encrypting user passwords..."
encrypt_credential drew-password /tmp/drew-password "$CREDS_DIR/drew-password.cred" || exit 1
encrypt_credential emily-password /tmp/emily-password "$CREDS_DIR/emily-password.cred" || exit 1
encrypt_credential bella-password /tmp/bella-password "$CREDS_DIR/bella-password.cred" || exit 1

echo "Encrypting WiFi credentials..."
encrypt_credential wifi-ssid /tmp/wifi-ssid "$CREDS_DIR/wifi-ssid.cred" || exit 1
encrypt_credential wifi-password /tmp/wifi-password "$CREDS_DIR/wifi-password.cred" || exit 1

# Set secure permissions on encrypted credentials
chmod 600 "$CREDS_DIR"/*.cred

echo "✓ All secrets encrypted and stored in $CREDS_DIR"

# Clean up ALL temp files containing secrets
echo "Securely cleaning up temporary files..."
shred -u /tmp/drew-rclone.conf /tmp/emily-rclone.conf /tmp/bella-rclone.conf 2>/dev/null || true
shred -u /tmp/drew-ssh-keys /tmp/emily-ssh-keys /tmp/bella-ssh-keys 2>/dev/null || true
shred -u /tmp/drew-password /tmp/emily-password /tmp/bella-password 2>/dev/null || true
shred -u /tmp/wifi-ssid /tmp/wifi-password 2>/dev/null || true
rm -f /tmp/drew-ssh-keys /tmp/emily-ssh-keys /tmp/bella-ssh-keys
rm -f /tmp/drew-password /tmp/emily-password /tmp/bella-password
rm -f /tmp/wifi-ssid /tmp/wifi-password

echo ""
echo "Step 4: Verifying machine configuration..."

cd /etc/nixos || {
  echo "ERROR: Cannot change to /etc/nixos directory"
  exit 1
}

# Verify host directory exists
if [ ! -d "hosts/$HOSTNAME" ]; then
  echo "ERROR: hosts/$HOSTNAME directory not found!"
  echo "This machine is not yet configured in the flake."
  exit 1
fi

# Verify hardware configuration exists
if [ ! -f "hosts/$HOSTNAME/hardware-configuration.nix" ]; then
  echo "ERROR: No hardware-configuration.nix found for $HOSTNAME!"
  exit 1
fi

echo "✓ Machine configuration ready for $HOSTNAME"

echo ""
echo "Step 4.5: Bootloader preflight..."

HOST_CONFIG_FILE="/etc/nixos/hosts/$HOSTNAME/configuration.nix"
HOST_HW_FILE="/etc/nixos/hosts/$HOSTNAME/hardware-configuration.nix"

detect_root_disk() {
  local root_src pk
  root_src=$(findmnt -no SOURCE / 2>/dev/null || true)
  if [ -z "$root_src" ]; then
    echo ""
    return 0
  fi

  if command -v lsblk >/dev/null 2>&1; then
    pk=$(lsblk -no PKNAME "$root_src" 2>/dev/null || true)
    if [ -n "$pk" ]; then
      echo "/dev/$pk"
      return 0
    fi
  fi

  case "$root_src" in
    /dev/nvme*n*p*) echo "${root_src%p*}" ;;
    /dev/sd[a-z][0-9]*) echo "${root_src%[0-9]*}" ;;
    /dev/vd[a-z][0-9]*) echo "${root_src%[0-9]*}" ;;
    *) echo "" ;;
  esac
}

patch_for_bios_grub() {
  local disk
  disk=$(detect_root_disk)
  if [ -z "$disk" ]; then
    disk="/dev/sda"
    echo "WARN: Could not detect install disk for GRUB; defaulting to $disk" >&2
  fi

  # Disable systemd-boot/UEFI knobs if present
  sed -i \
    -e 's/^\s*boot\.loader\.systemd-boot\.enable\s*=\s*true\s*;\s*$/  boot.loader.systemd-boot.enable = false;/' \
    -e 's/^\s*boot\.loader\.efi\.canTouchEfiVariables\s*=\s*true\s*;\s*$/  boot.loader.efi.canTouchEfiVariables = false;/' \
    "$HOST_CONFIG_FILE" || true

  # Ensure GRUB is enabled for BIOS installs
  if ! grep -qE '^\s*boot\.loader\.grub\.enable\s*=\s*true\s*;' "$HOST_CONFIG_FILE"; then
    cat >>"$HOST_CONFIG_FILE" <<EOF

  # Added by bootstrap (legacy BIOS install)
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "${disk}";
EOF
  else
    # Update grub device if already present
    if grep -qE '^\s*boot\.loader\.grub\.device\s*=\s*"[^"]+"\s*;' "$HOST_CONFIG_FILE"; then
      sed -i -E "s|^\s*boot\.loader\.grub\.device\s*=\s*\"[^\"]+\"\s*;\s*$|  boot.loader.grub.device = \"${disk}\";|" "$HOST_CONFIG_FILE" || true
    else
      printf '\n  boot.loader.grub.device = "%s";\n' "$disk" >>"$HOST_CONFIG_FILE"
    fi
  fi
}

patch_for_uefi_systemd_boot() {
  # Ensure an ESP is mounted before installing systemd-boot.
  local esp=""

  if mountpoint -q /boot/efi; then
    esp="/boot/efi"
  elif mountpoint -q /boot; then
    esp="/boot"
  elif [ -f "$HOST_HW_FILE" ] && grep -q 'fileSystems\."/boot/efi"' "$HOST_HW_FILE"; then
    mkdir -p /boot/efi
    mount /boot/efi 2>/dev/null || true
    mountpoint -q /boot/efi && esp="/boot/efi"
  elif [ -f "$HOST_HW_FILE" ] && grep -q 'fileSystems\."/boot"' "$HOST_HW_FILE"; then
    mkdir -p /boot
    mount /boot 2>/dev/null || true
    mountpoint -q /boot && esp="/boot"
  fi

  if [ -z "$esp" ]; then
    echo "ERROR: UEFI system detected but no EFI System Partition is mounted at /boot or /boot/efi."
    echo "Fix by mounting your ESP, then re-run: sudo nixos-rebuild switch --flake .#$HOSTNAME"
    exit 1
  fi

  # Ensure systemd-boot is enabled and GRUB is disabled.
  sed -i \
    -e 's/^\s*boot\.loader\.systemd-boot\.enable\s*=\s*false\s*;\s*$/  boot.loader.systemd-boot.enable = true;/' \
    -e 's/^\s*boot\.loader\.efi\.canTouchEfiVariables\s*=\s*false\s*;\s*$/  boot.loader.efi.canTouchEfiVariables = true;/' \
    "$HOST_CONFIG_FILE" || true

  if ! grep -qE '^\s*boot\.loader\.systemd-boot\.enable\s*=\s*true\s*;' "$HOST_CONFIG_FILE"; then
    cat >>"$HOST_CONFIG_FILE" <<EOF

  # Added by bootstrap (UEFI install)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
EOF
  fi
}

if [ ! -f "$HOST_CONFIG_FILE" ]; then
  echo "ERROR: Host configuration not found at $HOST_CONFIG_FILE"
  exit 1
fi

if [ -d /sys/firmware/efi ]; then
  echo "Detected UEFI boot"
  patch_for_uefi_systemd_boot
else
  echo "Detected legacy BIOS boot"
  patch_for_bios_grub
fi

echo ""
echo "Step 5: Applying NixOS configuration..."
echo "This will take several minutes (downloading packages)..."

echo "Building NixOS configuration..."
echo "This may take 10-30 minutes depending on internet speed..."

# Add hardware-configuration.nix to git so flake can see it
echo "Adding hardware-configuration.nix to git working tree..."
git add -f hosts/$HOSTNAME/hardware-configuration.nix || {
  echo "ERROR: Failed to add hardware-configuration.nix"
  exit 1
}

if ! sudo nixos-rebuild switch --flake .#$HOSTNAME; then
  echo ""
  echo "ERROR: nixos-rebuild failed!"
  echo "Check the error messages above for details."
  echo "Secrets are preserved in /tmp/nixos-secrets and /tmp/nixos-passwords"
  echo "You can retry with: cd /etc/nixos && sudo nixos-rebuild switch --flake .#$HOSTNAME"
  exit 1
fi

echo "✓ NixOS configuration applied successfully"

echo ""
echo "Step 6: Setting user passwords..."

# Verify users were created
for user in drew emily bella; do
  if ! id "$user" &>/dev/null; then
    echo "ERROR: User $user was not created by nixos-rebuild"
    exit 1
  fi
done
echo "✓ All users exist"

# Decrypt and set passwords from systemd-creds
echo "Setting passwords from encrypted credentials..."
DREW_PASS=$(systemd-creds decrypt "$CREDS_DIR/drew-password.cred" -) || { echo "ERROR: Failed to decrypt Drew's password"; exit 1; }
EMILY_PASS=$(systemd-creds decrypt "$CREDS_DIR/emily-password.cred" -) || { echo "ERROR: Failed to decrypt Emily's password"; exit 1; }
BELLA_PASS=$(systemd-creds decrypt "$CREDS_DIR/bella-password.cred" -) || { echo "ERROR: Failed to decrypt Bella's password"; exit 1; }

echo "drew:$DREW_PASS" | chpasswd || { echo "ERROR: Failed to set Drew's password"; exit 1; }
echo "emily:$EMILY_PASS" | chpasswd || { echo "ERROR: Failed to set Emily's password"; exit 1; }
echo "bella:$BELLA_PASS" | chpasswd || { echo "ERROR: Failed to set Bella's password"; exit 1; }

# Clear password variables
unset DREW_PASS EMILY_PASS BELLA_PASS

echo "✓ Passwords set for all users"

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
