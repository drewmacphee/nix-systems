# Making the Repository Private

If you want to make this repository private, here's what needs to change.

## Why It Matters

The bootstrap script currently does:
```bash
curl -L https://raw.githubusercontent.com/drewmacphee/nix-kids-laptop/main/bootstrap.sh | sudo bash
```

This won't work with a private repo because:
1. GitHub won't serve raw files from private repos without authentication
2. The bootstrap script clones the repo, which requires auth

## Solution: GitHub Deploy Key or Personal Access Token

### Option 1: GitHub Deploy Key (Recommended for Private Repos)

Deploy keys are read-only SSH keys that give access to a single repository.

#### Setup Steps:

**1. Generate a deploy key in Azure Key Vault**

```bash
# Generate SSH key specifically for deploy access
ssh-keygen -t ed25519 -f /tmp/deploy-key -C "nix-kids-laptop-deploy" -N ""

# Store the PRIVATE key in Key Vault
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name github-deploy-key \
  --file /tmp/deploy-key

# Keep the public key for GitHub
cat /tmp/deploy-key.pub

# Clean up
rm /tmp/deploy-key /tmp/deploy-key.pub
```

**2. Add deploy key to GitHub**

1. Go to: https://github.com/drewmacphee/nix-kids-laptop/settings/keys
2. Click "Add deploy key"
3. Title: "NixOS Bootstrap Deploy Key"
4. Paste the PUBLIC key (from step 1)
5. **Leave "Allow write access" UNCHECKED** (read-only is safer)
6. Click "Add key"

**3. Update bootstrap.sh**

Change the script to:
- Fetch the deploy key from Key Vault
- Use SSH instead of HTTPS for git clone
- Set up temporary SSH key for the clone

```bash
# In bootstrap.sh, change this section:

echo "Step 3: Fetching secrets from Azure Key Vault..."

# Add deploy key fetch
az keyvault secret show --vault-name ${VAULT_NAME} --name github-deploy-key --query value -o tsv > /tmp/deploy-key
chmod 600 /tmp/deploy-key

# ... rest of secret fetching ...

echo "Step 4: Cloning configuration repository..."
# Setup SSH for git
mkdir -p /root/.ssh
ssh-keyscan github.com >> /root/.ssh/known_hosts
export GIT_SSH_COMMAND="ssh -i /tmp/deploy-key -o StrictHostKeyChecking=no"

if [ -d "/etc/nixos/.git" ]; then
  echo "Config already exists, pulling latest..."
  cd /etc/nixos
  git pull
else
  # Backup existing config
  if [ -d "/etc/nixos" ]; then
    mv /etc/nixos /etc/nixos.backup.$(date +%Y%m%d-%H%M%S)
  fi
  # Use SSH URL instead of HTTPS
  git clone git@github.com:drewmacphee/nix-kids-laptop.git /etc/nixos
fi

# Clean up deploy key
rm -f /tmp/deploy-key
unset GIT_SSH_COMMAND
```

**4. Update configuration.nix auto-upgrade**

Change line 107 in `configuration.nix`:

```nix
# From:
flake = "github:drewmacphee/nix-kids-laptop#kids-laptop";

# To: (disable auto-upgrade from GitHub, or use SSH)
# Option A: Disable auto-upgrade from GitHub
system.autoUpgrade.enable = false;

# Option B: Use local flake path
flake = "/etc/nixos#kids-laptop";
```

### Option 2: Personal Access Token (Simpler but Less Secure)

**1. Create GitHub Personal Access Token**

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name: "NixOS Bootstrap"
4. Expiration: 90 days (or longer)
5. Scopes: Check **only** `repo` (Full control of private repositories)
6. Click "Generate token"
7. **COPY THE TOKEN** (you won't see it again!)

**2. Store token in Key Vault**

```bash
echo "ghp_yourTokenHere" > /tmp/github-token
az keyvault secret set \
  --vault-name nix-kids-laptop \
  --name github-token \
  --file /tmp/github-token
rm /tmp/github-token
```

**3. Update bootstrap.sh**

```bash
# Fetch token
echo 'Step 3: Fetching secrets from Azure Key Vault...'
GITHUB_TOKEN=$(az keyvault secret show --vault-name ${VAULT_NAME} --name github-token --query value -o tsv)

# ... other secrets ...

echo "Step 4: Cloning configuration repository..."
if [ -d "/etc/nixos/.git" ]; then
  cd /etc/nixos
  git pull
else
  if [ -d "/etc/nixos" ]; then
    mv /etc/nixos /etc/nixos.backup.$(date +%Y%m%d-%H%M%S)
  fi
  # Clone with token authentication
  git clone https://${GITHUB_TOKEN}@github.com/drewmacphee/nix-kids-laptop.git /etc/nixos
fi

# Clean up token from memory
unset GITHUB_TOKEN
```

**Downsides:**
- Token expires (needs renewal)
- More powerful than needed (access to all your private repos)
- Token visible in process list briefly during clone

### Option 3: Hybrid - Public Bootstrap, Private Config

Keep `bootstrap.sh` in a public repo, but reference a private config repo.

**Structure:**
- `nix-kids-laptop-bootstrap` (public) - Contains only bootstrap.sh
- `nix-kids-laptop` (private) - Contains all NixOS configs

**Benefits:**
- Easy to bootstrap (public URL)
- Configs stay private
- Best of both worlds

## Comparison

| Method | Security | Maintenance | Complexity |
|--------|----------|-------------|------------|
| Deploy Key | ⭐⭐⭐⭐⭐ | Easy | Medium |
| PAT | ⭐⭐⭐ | Need to renew | Low |
| Hybrid | ⭐⭐⭐⭐ | Easy | Medium |
| Keep Public | ⭐⭐ (secrets in KV) | Easiest | None |

## Recommendation

**For your use case, I recommend keeping the repo PUBLIC because:**

1. ✅ **No secrets are in the repo** - Everything sensitive is in Azure Key Vault
2. ✅ **Easier to use** - One-line curl command works anywhere
3. ✅ **Easier to maintain** - No token renewal, no extra auth setup
4. ✅ **Easier to share** - Can help others with similar setups

**What's actually in the repo:**
- NixOS configuration files (system settings, package lists)
- Documentation
- Bootstrap script
- No passwords, no SSH keys, no API tokens, no OneDrive configs

**If you still want it private:**
- Use **Deploy Key** method (most secure, no expiration)
- Requires updating bootstrap.sh and adding 1 more secret to Key Vault

## Making It Private Now

If you want to make it private:

```bash
# On GitHub website:
# 1. Go to https://github.com/drewmacphee/nix-kids-laptop/settings
# 2. Scroll to "Danger Zone"
# 3. Click "Change visibility" → "Make private"
# 4. Follow confirmation prompts

# Then implement Option 1 (Deploy Key) above
```

## Security Considerations

**Public repo risks:**
- ✅ People can see your system configuration
- ✅ People can see you use GNOME, Steam, etc.
- ✅ People can see usernames (Drew, Emily, Bella)
- ❌ Cannot see passwords (in Key Vault)
- ❌ Cannot see SSH keys (in Key Vault)
- ❌ Cannot see OneDrive configs (in Key Vault)
- ❌ Cannot see any actual secrets

**Private repo benefits:**
- ✅ Configuration details hidden
- ✅ Usernames hidden
- ✅ Package choices hidden
- ❌ More complex to bootstrap
- ❌ Requires token/key management

## My Verdict

Keep it **public**. The only "sensitive" info is that you have kids named Emily and Bella who use a NixOS laptop with Steam. All actual secrets are safely in Azure Key Vault, which is the right place for them.

But if you prefer privacy, use the **Deploy Key** method - it's the most secure option for private repos.
