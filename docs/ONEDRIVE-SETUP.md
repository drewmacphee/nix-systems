# OneDrive Setup Guide

This guide walks through setting up OneDrive for each user account.

## User OneDrive Accounts

- **Drew**: drewjamesross@outlook.com
- **Emily**: emilykamacphee@outlook.com
- **Bella**: isabellaleblanc@outlook.com

## Setup Process for Each User

You'll need to run this process three times, once for each user account.

### Step 1: Configure rclone for Drew

```bash
# Install rclone temporarily
nix-shell -p rclone

# Start configuration
rclone config

# Follow these prompts:
# n) New remote
# name> onedrive
# Storage> onedrive (type number for onedrive, usually 31)
# client_id> (leave blank, press enter)
# client_secret> (leave blank, press enter)
# region> 1 (Microsoft Cloud Global)
# Edit advanced config? n
# Use auto config? y (will open browser)
# 
# Browser opens - Login with: drewjamesross@outlook.com
# 
# Choose account type: 1 (OneDrive Personal or Business)
# Confirm: y
```

### Step 2: Save Drew's Config

```bash
# Upload the config to Azure Key Vault
az keyvault secret set \
	--vault-name nix-kids-laptop \
	--name drew-rclone-config \
	--file ~/.config/rclone/rclone.conf
```

### Step 3: Configure rclone for Emily

```bash
# Clear previous config
rm ~/.config/rclone/rclone.conf

# Start fresh configuration
rclone config

# Follow same prompts as Drew, but:
# Login with: emilykamacphee@outlook.com

# Upload the config to Azure Key Vault
az keyvault secret set \
	--vault-name nix-kids-laptop \
	--name emily-rclone-config \
	--file ~/.config/rclone/rclone.conf
```

### Step 4: Configure rclone for Bella

```bash
# Clear previous config
rm ~/.config/rclone/rclone.conf

# Start fresh configuration
rclone config

# Follow same prompts, but:
# Login with: isabellaleblanc@outlook.com

# Upload the config to Azure Key Vault
az keyvault secret set \
	--vault-name nix-kids-laptop \
	--name bella-rclone-config \
	--file ~/.config/rclone/rclone.conf
```

### Step 5: Repeat for each user

Once all three rclone configs are uploaded, run the bootstrap script on the target machine.

## Testing After Bootstrap

After running the bootstrap script and rebooting, each user can test their OneDrive:

### For Drew:
```bash
su - drew
systemctl --user status onedrive
ls ~/OneDrive
```

### For Emily:
```bash
su - emily
systemctl --user status onedrive
ls ~/OneDrive
```

### For Bella:
```bash
su - bella
systemctl --user status onedrive
ls ~/OneDrive
```

## Troubleshooting

**OneDrive not mounting:**
```bash
# Check service logs
journalctl --user -u onedrive -f

# Test rclone manually
rclone lsd onedrive:

# Remount manually
rclone mount onedrive: ~/OneDrive --vfs-cache-mode writes
```

**Token expired:**
- Re-run `rclone config` and reconnect the account
- Upload the updated `~/.config/rclone/rclone.conf` to Key Vault
- Re-run bootstrap (or re-encrypt locally and restart the decrypt service)

## Notes

- Each user has their own separate OneDrive account
- Files are automatically synced when users are logged in
- The systemd service starts automatically on user login
- OneDrive files appear at `/home/<username>/OneDrive`
