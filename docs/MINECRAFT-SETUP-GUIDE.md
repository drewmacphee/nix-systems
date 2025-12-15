# Minecraft/PrismLauncher Setup Guide

This guide covers how to configure PrismLauncher (Minecraft) for each user with their Microsoft accounts and OneDrive profile storage.

## Overview

**Goal:** Each user has their own Minecraft instances stored in their OneDrive, so:
- Saves/worlds sync across devices
- Profiles persist if laptop is wiped
- Each user has their own Microsoft account for multiplayer

## Architecture Options

### Option 1: OneDrive Profile Storage (Recommended)

**Pros:**
- ✅ Minecraft saves sync to cloud automatically
- ✅ Survives laptop wipes/reinstalls
- ✅ Can access same worlds from other devices
- ✅ Automatic backup via OneDrive

**Cons:**
- ⚠️ OneDrive sync can be slow for large modpacks
- ⚠️ Potential sync conflicts if playing on multiple devices simultaneously

### Option 2: Local Storage with Selective OneDrive Sync

**Pros:**
- ✅ Fast game performance (local storage)
- ✅ Important saves backed up to OneDrive
- ✅ No sync conflicts

**Cons:**
- ⚠️ Requires manual backup setup
- ⚠️ Not fully automatic

### Option 3: Hybrid (Best of Both)

Store profiles in OneDrive, but exclude large cache/mod files:
- Game instances: OneDrive (profiles, worlds, configs)
- Assets/libraries: Local (large, downloadable files)
- Screenshots: OneDrive (memories!)

## Implementation

### Automatic Setup via NixOS Configuration

We can pre-configure PrismLauncher for each user in their home-manager config:

```nix
# In home-drew.nix, home-emily.nix, home-bella.nix
home.file.".local/share/PrismLauncher/prismlauncher.cfg".text = ''
  [General]
  InstanceDir=/home/USERNAME/OneDrive/Minecraft/instances
  CentralModsDir=/home/USERNAME/OneDrive/Minecraft/mods
  IconsDir=/home/USERNAME/OneDrive/Minecraft/icons
  
  [MainWindow]
  geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x3\0\0\0\0\x2\x80\0\0\x1\x90\0\0\x5\x7f\0\0\x4\x8f\0\0\x2\x80\0\0\x1\xac\0\0\x5\x7f\0\0\x4\x8f\0\0\0\0\0\0\0\0\a\x80\0\0\x2\x80\0\0\x1\xac\0\0\x5\x7f\0\0\x4\x8f)
  
  [Accounts]
  # Microsoft account will be added on first launch
  UseAccountForInstance=true
'';

# Create OneDrive Minecraft directories
home.activation.createMinecraftDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
  $DRY_RUN_CMD mkdir -p $HOME/OneDrive/Minecraft/{instances,mods,icons,screenshots}
  $DRY_RUN_CMD ln -sf $HOME/OneDrive/Minecraft/screenshots $HOME/Pictures/Minecraft
'';
```

### Manual First-Time Setup (Per User)

Each user needs to link their Microsoft account once:

1. **Launch PrismLauncher**
2. **Click "Profiles" → "Manage Accounts"**
3. **Click "Add Microsoft"**
4. **Login with their Microsoft account:**
   - Drew: drewjamesross@outlook.com
   - Emily: emilykamacphee@outlook.com
   - Bella: isabellaleblanc@outlook.com
5. **Set as default account**

This stores the account credentials locally (encrypted by PrismLauncher).

### OneDrive Folder Structure

```
~/OneDrive/Minecraft/
├── instances/               # Game instances (1.20.1, modpacks, etc.)
│   ├── 1.20.1-Vanilla/
│   │   ├── saves/          # World saves (IMPORTANT)
│   │   ├── resourcepacks/
│   │   ├── shaderpacks/
│   │   └── screenshots/
│   └── FTB-Modpack/
├── mods/                   # Shared mod library
├── icons/                  # Instance icons
└── screenshots/            # All screenshots
```

### Performance Optimization

To avoid syncing large files that can be re-downloaded:

```nix
# In configuration.nix - create .stignore for OneDrive
systemd.user.services.prism-onedrive-excludes = {
  description = "Setup PrismLauncher OneDrive exclusions";
  wantedBy = [ "default.target" ];
  
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  
  script = ''
    # Create .stignore to exclude large cached files from sync
    cat > ~/OneDrive/Minecraft/.stignore << 'EOF'
# Exclude large cache files from OneDrive sync
**/libraries/**
**/assets/**
**/.minecraft/versions/**
**/crash-reports/**
**/logs/**
*.jar
*.zip
EOF
  '';
};
```

## Pre-Configuration We Can Do

### What We CAN Pre-Configure:

✅ **PrismLauncher data directory** → Point to OneDrive
✅ **Instance storage location** → `~/OneDrive/Minecraft/instances`
✅ **Screenshot location** → `~/OneDrive/Minecraft/screenshots`
✅ **Default Java settings** → Memory allocation, JVM args
✅ **Create directory structure** → Empty folders ready to use

### What Users MUST Do First-Time:

❌ **Microsoft account login** → Must be done interactively (OAuth)
❌ **Accept Minecraft EULA** → Legal requirement
❌ **Create first instance** → User choice of version

### What We COULD Pre-Configure (Advanced):

⚠️ **Pre-create vanilla instances** → 1.20.1, 1.19.4, etc.
⚠️ **Install common modpacks** → FTB, Curseforge packs
⚠️ **Pre-accept EULA** → Via config file

## Recommended Approach

### 1. Update Home Manager Configs

Add to `home-drew.nix`, `home-emily.nix`, `home-bella.nix`:

```nix
{ config, pkgs, ... }:

{
  # ... existing config ...

  # PrismLauncher configuration
  home.file.".local/share/PrismLauncher/prismlauncher.cfg".text = ''
    [General]
    InstanceDir=${config.home.homeDirectory}/OneDrive/Minecraft/instances
    IconsDir=${config.home.homeDirectory}/OneDrive/Minecraft/icons
    CentralModsDir=${config.home.homeDirectory}/OneDrive/Minecraft/mods
    
    [Java]
    MaxMemAlloc=4096
    MinMemAlloc=2048
    PermGen=128
    
    [MainWindow]
    centralModsDir=${config.home.homeDirectory}/OneDrive/Minecraft/mods
  '';

  # Create Minecraft directory structure in OneDrive
  home.activation.setupMinecraft = config.lib.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${config.home.homeDirectory}/OneDrive/Minecraft/{instances,mods,icons,resourcepacks,screenshots}
    
    # Create EULA acceptance file
    cat > ${config.home.homeDirectory}/OneDrive/Minecraft/eula.txt << 'EOF'
# By changing the setting below to TRUE you are indicating your agreement to our EULA (https://aka.ms/MinecraftEULA).
eula=true
EOF
    
    # Create README for users
    cat > ${config.home.homeDirectory}/OneDrive/Minecraft/README.txt << 'EOF'
This folder contains your Minecraft game data.

Your worlds, screenshots, and settings are stored here and 
automatically synced to OneDrive.

On first launch:
1. Open PrismLauncher
2. Click "Profiles" -> "Manage Accounts"
3. Add your Microsoft account
4. Create or import an instance

Happy mining!
EOF
  '';
}
```

### 2. Create a Setup Script for Users

Create `~/minecraft-setup.sh` that users run on first login:

```bash
#!/bin/bash
# Minecraft First-Time Setup Helper

echo "Minecraft Setup for $USER"
echo "=========================="
echo ""
echo "Your Minecraft data is stored in: ~/OneDrive/Minecraft"
echo "This folder syncs to the cloud automatically."
echo ""
echo "Next steps:"
echo "1. Launch PrismLauncher from the application menu"
echo "2. Add your Microsoft account (click 'Profiles' -> 'Manage Accounts')"
echo "3. Create your first instance!"
echo ""
echo "Your Microsoft account:"
case $USER in
  drew)
    echo "  drewjamesross@outlook.com"
    ;;
  emily)
    echo "  emilykamacphee@outlook.com"
    ;;
  bella)
    echo "  isabellaleblanc@outlook.com"
    ;;
esac
echo ""
read -p "Press Enter to launch PrismLauncher..."
prismlauncher &
```

### 3. Alternative: Pre-Store Microsoft Account Tokens in Key Vault

**Advanced Option:** Store Microsoft OAuth tokens in Key Vault and pre-populate them.

**Pros:**
- Fully automatic setup
- Users can play immediately

**Cons:**
- Complex to implement
- Security concerns (storing game account tokens)
- Tokens expire regularly
- Against Microsoft ToS potentially

**Verdict:** Not recommended. Better to have users login once interactively.

## Implementation Plan

### Phase 1: Basic Setup (Recommended)

1. Update home-manager configs to point PrismLauncher to OneDrive
2. Create directory structure automatically
3. Pre-accept EULA
4. Add README for users

**Result:** Users login to Microsoft account once, then everything syncs.

### Phase 2: Enhanced (Optional)

1. Pre-create popular vanilla instances (1.20.1, 1.19.4)
2. Pre-install performance mods (Sodium, Lithium)
3. Pre-configure resource packs folder
4. Setup screenshot hotkey to save to OneDrive

### Phase 3: Advanced (Optional)

1. Pre-install popular modpacks
2. Setup automatic backup script
3. Configure multiplayer server favorites
4. Setup shader packs

## Security Considerations

**Microsoft Account Credentials:**
- ❌ Never store passwords in plain text
- ❌ Don't commit account files to git
- ✅ Let PrismLauncher handle OAuth tokens securely
- ✅ Tokens stored in keyring, encrypted at rest

**OneDrive Syncing:**
- ✅ Game saves are personal data, safe in OneDrive
- ✅ OAuth tokens are NOT synced (stored locally)
- ⚠️ Don't enable OneDrive on untrusted devices

## Conclusion

**Best approach:**

1. ✅ Pre-configure PrismLauncher to use OneDrive directories
2. ✅ Create folder structure automatically
3. ✅ Pre-accept EULA
4. ❌ DON'T try to pre-configure Microsoft accounts
5. ✅ Users add Microsoft account on first launch (takes 30 seconds)

This gives you:
- Automatic cloud backup of all worlds/saves
- Persistent profiles across reinstalls
- Per-user Microsoft accounts for multiplayer
- Clean, automatic setup

**Want me to implement this in the home-manager configs?**
