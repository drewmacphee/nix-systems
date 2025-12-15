# PrismLauncher Account Storage Analysis

## Where PrismLauncher Stores Accounts

### Account Data Location

PrismLauncher stores account data in:
```
~/.local/share/PrismLauncher/accounts/
└── accounts.json
```

Or on Linux with XDG:
```
$XDG_DATA_HOME/PrismLauncher/accounts/
└── accounts.json
```

### What's in accounts.json?

**Structure:**
```json
{
  "accounts": [
    {
      "type": "MSA",  // Microsoft Account
      "profile": {
        "id": "uuid-here",
        "name": "PlayerName"
      },
      "data": {
        "token": "encrypted-refresh-token",
        "client_id": "...",
        "token_endpoint": "https://login.microsoftonline.com/...",
        "expiry_time": 1234567890
      }
    }
  ],
  "activeAccount": "uuid-of-active-account"
}
```

### Important Details:

1. **NOT Stored in Instance Directory**
   - Accounts are stored in `~/.local/share/PrismLauncher/`
   - Instances are stored wherever you configure (e.g., `~/OneDrive/Minecraft/instances`)
   - **They are separate!**

2. **Token Security**
   - Tokens are encrypted by PrismLauncher
   - Encryption key is stored locally on the system
   - Uses system keyring/keychain when available

3. **Platform-Specific Paths:**
   - Linux: `~/.local/share/PrismLauncher/`
   - Windows: `%APPDATA%\PrismLauncher\`
   - macOS: `~/Library/Application Support/PrismLauncher/`

## The Problem with Syncing Accounts

### Why Accounts SHOULDN'T Go in OneDrive:

❌ **Security Risk**
- Encrypted tokens + encryption keys would both be in OneDrive
- Anyone with OneDrive access could extract tokens
- Violates principle of separating secrets from data

❌ **System-Specific**
- Encryption keys are tied to the local system
- Tokens encrypted on one machine won't work on another
- Would require re-encryption for each device

❌ **Token Expiry**
- OAuth refresh tokens expire
- Syncing old tokens across devices causes conflicts
- Better to have each device manage its own tokens

### What SHOULD Go in OneDrive:

✅ **Game Data**
- World saves (`instances/*/saves/`)
- Screenshots (`instances/*/screenshots/`)
- Resource packs (`instances/*/resourcepacks/`)
- Shader packs (`instances/*/shaderpacks/`)
- Configuration files (`instances/*/options.txt`)

✅ **Instance Metadata**
- Instance configs (`instances/*/instance.cfg`)
- Mod lists (`instances/*/mods/`)
- Server lists (`instances/*/servers.dat`)

❌ **Should NOT Sync**
- Account data (`~/.local/share/PrismLauncher/accounts/`)
- Application settings (`~/.local/share/PrismLauncher/prismlauncher.cfg`)
- Cache files (`~/.cache/PrismLauncher/`)

## Recommended Architecture

### Split Storage:

```
Local (~/.local/share/PrismLauncher/):
├── accounts/
│   └── accounts.json          ← STAYS LOCAL (security)
├── prismlauncher.cfg          ← Config points to OneDrive
├── cache/                     ← STAYS LOCAL (performance)
└── assets/                    ← STAYS LOCAL (downloadable)

OneDrive (~/OneDrive/Minecraft/):
├── instances/                 ← SYNCS (game data)
│   ├── 1.20.1-Vanilla/
│   │   ├── saves/            ← SYNCS (worlds)
│   │   ├── screenshots/      ← SYNCS (memories)
│   │   ├── options.txt       ← SYNCS (settings)
│   │   └── servers.dat       ← SYNCS (server list)
│   └── FTB-Modpack/
├── mods/                      ← SYNCS (shared mods)
├── resourcepacks/             ← SYNCS (textures)
└── screenshots/               ← SYNCS (global screenshots)
```

### Why This Works:

✅ **Security**: Accounts stay local, encrypted per-device
✅ **Performance**: Cache/assets local for speed
✅ **Portability**: Game data syncs everywhere
✅ **Simplicity**: Each device manages own auth

## Implementation Strategy

### What We Pre-Configure:

```nix
# In home-*.nix
home.file.".local/share/PrismLauncher/prismlauncher.cfg".text = ''
  [General]
  # Point instances to OneDrive
  InstanceDir=${config.home.homeDirectory}/OneDrive/Minecraft/instances
  IconsDir=${config.home.homeDirectory}/OneDrive/Minecraft/icons
  
  # Keep these LOCAL for performance
  # (these are defaults, but being explicit)
  AssetsDir=${config.home.homeDirectory}/.local/share/PrismLauncher/assets
  LibrariesDir=${config.home.homeDirectory}/.local/share/PrismLauncher/libraries
  
  [Java]
  MaxMemAlloc=4096
  MinMemAlloc=2048
'';

# Accounts directory stays in default location (~/.local/share/PrismLauncher/accounts/)
# This is good - keeps auth local and secure
```

### What Users Do Once Per Device:

1. Launch PrismLauncher
2. Click "Profiles" → "Manage Accounts"
3. Click "Add Microsoft"
4. Login (drewjamesross@outlook.com / emilykamacphee@outlook.com / isabellaleblanc@outlook.com)

**This creates** `~/.local/share/PrismLauncher/accounts/accounts.json` **locally**

### After First Setup:

✅ User's worlds are in `~/OneDrive/Minecraft/instances/*/saves/`
✅ Screenshots sync to `~/OneDrive/Minecraft/instances/*/screenshots/`
✅ Settings sync via `instances/*/options.txt`
✅ Account credentials stay local and secure

## If Laptop is Wiped:

### Scenario: NixOS reinstall from scratch

1. **Bootstrap runs** → Sets up NixOS, installs PrismLauncher
2. **OneDrive mounts** → `~/OneDrive/Minecraft/` appears with all game data
3. **PrismLauncher config points to OneDrive** → Sees all instances
4. **User launches PrismLauncher** → Sees all their worlds!
5. **User adds Microsoft account** → Takes 30 seconds
6. **Play immediately** → All worlds intact, just re-authenticated

### What Survives:

✅ All world saves
✅ All screenshots  
✅ All configurations
✅ All mods
✅ Server lists

### What Needs Re-doing:

❌ Microsoft account login (30 seconds)

## Alternative: Could We Sync Accounts?

### Technically Possible but NOT RECOMMENDED:

**Option A: Symlink accounts to OneDrive**
```bash
ln -s ~/OneDrive/Minecraft/accounts ~/.local/share/PrismLauncher/accounts
```

**Problems:**
- Encryption keys still local → tokens won't work across devices
- Sync conflicts if used on multiple devices
- Security risk if OneDrive compromised

**Option B: Store encrypted tokens in Key Vault**

**Problems:**
- Tokens expire every ~24 hours (access tokens) or ~90 days (refresh tokens)
- Would need automation to refresh and re-upload
- Complex OAuth flow to implement
- Microsoft might rate-limit/block automated token refresh
- Violates spirit of OAuth (user should consent per device)

## Verdict

### ✅ DO:
- Store game instances in OneDrive
- Store worlds/saves in OneDrive
- Store screenshots in OneDrive
- Point PrismLauncher config to OneDrive

### ❌ DON'T:
- Store accounts in OneDrive (security)
- Store cache in OneDrive (performance)
- Store assets/libraries in OneDrive (unnecessary, large)

### 🤷 Compromise:
- Users add Microsoft account once per device
- Takes 30 seconds
- Proper security model
- No complex automation needed

## Conclusion

**PrismLauncher stores accounts in `~/.local/share/PrismLauncher/accounts/`**

This is **separate** from instance data and **should stay local** because:

1. **Security**: Encrypted tokens belong on the device
2. **System-specific**: Encryption is per-device
3. **OAuth compliance**: Users should authenticate per device
4. **Simplicity**: No complex token management needed

**Recommended setup:**
- Game data → OneDrive ✅
- Accounts → Local ✅  
- Users authenticate once per device ✅
- 30 seconds of setup, lifetime of benefit ✅

**This is the right architecture!** Don't overthink it. 😊
