# Azure Key Vault Secrets Reference

This document describes what secrets should be stored in Azure Key Vault to streamline the bootstrap process.

## Current Approach vs. Optimized Approach

### Current (Basic):
- Only `age-identity` stored in Key Vault
- All other secrets encrypted with agenix and stored in git
- Requires pre-setup: generate age key, configure rclone, encrypt everything, commit to git

### Optimized (Recommended):
- Store ALL secrets directly in Key Vault
- Bootstrap script fetches everything at install time
- No need to pre-encrypt secrets or maintain agenix files in git
- Easier to rotate/update secrets without git commits

## Recommended Key Vault Secrets

### Authentication Secrets

**1. `age-identity`** (Current)
- The age private key for decrypting agenix secrets
- Still useful if you want to keep some secrets in git

**2. `drew-ssh-authorized-keys`**
- Drew's SSH public keys (newline separated)
- Allows immediate SSH access after bootstrap

**3. `emily-ssh-authorized-keys`**
- Emily's SSH public keys

**4. `bella-ssh-authorized-keys`**
- Bella's SSH public keys

### OneDrive Secrets

**5. `drew-rclone-config`**
- Complete rclone.conf for Drew's OneDrive
- Includes OAuth tokens for drewjamesross@outlook.com

**6. `emily-rclone-config`**
- Complete rclone.conf for Emily's OneDrive
- Includes OAuth tokens for emilykamacphee@outlook.com

**7. `bella-rclone-config`**
- Complete rclone.conf for Bella's OneDrive
- Includes OAuth tokens for isabellaleblanc@outlook.com

### Optional Additional Secrets

**8. `wifi-passwords`** (JSON format)
```json
{
  "HomeNetwork": "password123",
  "SchoolNetwork": "schoolpass"
}
```

**9. `github-deploy-key`**
- Private SSH key for accessing private repos
- Useful if you make the config repo private later

**10. `user-passwords-hashed`** (JSON format)
```json
{
  "drew": "$6$rounds=656000$...",
  "emily": "$6$rounds=656000$...",
  "bella": "$6$rounds=656000$..."
}
```

## Benefits of Key Vault Approach

### Pros:
1. **No pre-setup needed** - Just run bootstrap, login to Azure, done
2. **Secret rotation** - Update secrets in Key Vault, re-run bootstrap
3. **No git commits** - Sensitive data never touches git (even encrypted)
4. **Centralized** - All secrets in one place
5. **Access control** - Azure RBAC controls who can fetch secrets
6. **Audit logging** - Azure tracks all secret access

### Cons:
1. **Azure dependency** - Must have internet + Azure access to restore
2. **Less portable** - Can't fully restore without Azure account
3. **Cost** - Key Vault has small costs ($0.03/10k operations)

## Hybrid Approach (Best of Both Worlds)

**Store in Key Vault:**
- Frequently changing secrets (OAuth tokens, passwords)
- Bootstrap essentials (age key, SSH keys)

**Store in Git (agenix encrypted):**
- Static configs that rarely change
- Secrets you want version controlled
- Backup in case Key Vault unavailable

## Implementation Steps

### 1. Store rclone configs in Key Vault

```bash
# Configure rclone for each user first (see ONEDRIVE-SETUP.md)
# Then store in Key Vault instead of encrypting with agenix:

# Drew's config
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name drew-rclone-config \
  --file ~/.config/rclone/rclone.conf

# Emily's config (after reconfiguring for her account)
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name emily-rclone-config \
  --file ~/.config/rclone/rclone.conf

# Bella's config (after reconfiguring for her account)
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name bella-rclone-config \
  --file ~/.config/rclone/rclone.conf
```

### 2. Store SSH authorized keys

```bash
# Create authorized_keys file with your public keys
cat ~/.ssh/id_ed25519.pub > /tmp/authorized_keys

# Store for each user
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
```

### 3. Update bootstrap.sh

The bootstrap script would be enhanced to fetch all secrets:

```bash
# Fetch all secrets at once
az keyvault secret show --vault-name nix-kids-laptop --name age-identity --query value -o tsv > /tmp/age-key.txt
az keyvault secret show --vault-name nix-kids-laptop --name drew-rclone-config --query value -o tsv > /tmp/drew-rclone.conf
az keyvault secret show --vault-name nix-kids-laptop --name emily-rclone-config --query value -o tsv > /tmp/emily-rclone.conf
az keyvault secret show --vault-name nix-kids-laptop --name bella-rclone-config --query value -o tsv > /tmp/bella-rclone.conf
az keyvault secret show --vault-name nix-kids-laptop --name drew-ssh-authorized-keys --query value -o tsv > /tmp/drew-ssh-keys
az keyvault secret show --vault-name nix-kids-laptop --name emily-ssh-authorized-keys --query value -o tsv > /tmp/emily-ssh-keys
az keyvault secret show --vault-name nix-kids-laptop --name bella-ssh-authorized-keys --query value -o tsv > /tmp/bella-ssh-keys

# Place them where NixOS expects
mkdir -p /tmp/secrets
cp /tmp/drew-rclone.conf /tmp/secrets/
cp /tmp/emily-rclone.conf /tmp/secrets/
cp /tmp/bella-rclone.conf /tmp/secrets/
cp /tmp/drew-ssh-keys /tmp/secrets/
cp /tmp/emily-ssh-keys /tmp/secrets/
cp /tmp/bella-ssh-keys /tmp/secrets/
```

### 4. Simplify NixOS config

You could eliminate `secrets.nix` and `agenix` entirely, or use a hybrid approach where bootstrap script creates the secret files directly.

## Recommendation

For your use case, I recommend **storing rclone configs in Key Vault** because:
1. OAuth tokens expire and need rotation
2. You don't want to re-encrypt and commit every time
3. It's the most tedious part of setup

Keep SSH keys in agenix/git because:
1. They rarely change
2. You want them version controlled
3. Provides offline backup capability

Would you like me to implement this hybrid approach?
