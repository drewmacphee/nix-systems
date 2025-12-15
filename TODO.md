# TODO - Remaining Setup Tasks

## ✅ Completed
- [x] Created NixOS configuration files
- [x] Setup Azure Key Vault
- [x] Generated SSH key
- [x] Uploaded SSH keys to Key Vault (drew, emily, bella)
- [x] Created bootstrap script
- [x] Created documentation

## ⚠️ Still Need To Do

### 1. Configure rclone for OneDrive (Required before first bootstrap)

You need to configure rclone for each user's OneDrive account and upload to Key Vault.

**For Drew (drewjamesross@outlook.com):**
```bash
# Install rclone (on Windows)
winget install Rclone.Rclone

# Or download from: https://rclone.org/downloads/

# Configure OneDrive
rclone config
# - name: onedrive
# - storage: onedrive (option 31)
# - Leave client_id/secret blank
# - region: 1 (Global)
# - Use auto config: Yes (opens browser)
# - Login with: drewjamesross@outlook.com
# - Account type: 1 (OneDrive Personal)

# Upload to Key Vault
az keyvault secret set --vault-name nix-kids-laptop --name drew-rclone-config --file "$env:APPDATA\rclone\rclone.conf"
```

**For Emily (emilykamacphee@outlook.com):**
```bash
# Clear previous config
Remove-Item "$env:APPDATA\rclone\rclone.conf"

# Configure for Emily
rclone config
# Login with: emilykamacphee@outlook.com

# Upload to Key Vault
az keyvault secret set --vault-name nix-kids-laptop --name emily-rclone-config --file "$env:APPDATA\rclone\rclone.conf"
```

**For Bella (isabellaleblanc@outlook.com):**
```bash
# Clear previous config
Remove-Item "$env:APPDATA\rclone\rclone.conf"

# Configure for Bella
rclone config
# Login with: isabellaleblanc@outlook.com

# Upload to Key Vault
az keyvault secret set --vault-name nix-kids-laptop --name bella-rclone-config --file "$env:APPDATA\rclone\rclone.conf"
```

### 2. Verify All Secrets in Key Vault

```bash
az keyvault secret list --vault-name nix-kids-laptop --query "[].name" -o table
```

Should show all 6 secrets:
- bella-ssh-authorized-keys
- drew-ssh-authorized-keys
- emily-ssh-authorized-keys
- bella-rclone-config
- drew-rclone-config
- emily-rclone-config

### 3. Push to GitHub

```bash
cd C:\git\nix-kids-laptop
git add .
git commit -m "Initial NixOS kids laptop configuration"
git push
```

### 4. Test Bootstrap Script URL

```bash
curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh
```

Should display the bootstrap script content.

### 5. Test on NixOS

Once rclone configs are uploaded:
1. Install NixOS minimal on test VM or laptop
2. Run: `curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash`
3. Login with Microsoft account when prompted
4. Wait for installation
5. Reboot

## Notes

**Current Status:**
- ✅ SSH access will work (keys uploaded)
- ⚠️ OneDrive will NOT work until rclone configs uploaded
- ✅ System packages, Steam, Minecraft will install fine
- ✅ User accounts will be created
- ✅ GNOME desktop will be configured

**OneDrive configs must be done before production use** to enable cloud file sync!
