# System Updates and Maintenance

## 🔄 How Updates Work in NixOS

Unlike traditional Linux distributions, NixOS doesn't modify your system in-place. Instead, it:

1. **Builds** a completely new system configuration
2. **Tests** that the build succeeds
3. **Switches** atomically to the new version
4. **Keeps** the old version in the bootloader for rollback

This means **updates can never break your system permanently** - you can always roll back at boot.

---

## ⚙️ Automatic Update Configuration

### Current Settings

Your system is configured with **automatic updates**:

```nix
system.autoUpgrade = {
  enable = true;
  allowReboot = false;  # Never interrupts usage
  dates = "03:00";      # Runs at 3am daily
  flake = "github:drewmacphee/nix-systems";
};
```

### What Happens

**Every night at 3am**:
1. System checks GitHub for configuration updates
2. Downloads latest packages from nixos-24.05 branch
3. Builds new system generation
4. Prepares it for activation
5. **Waits for manual reboot** (never interrupts)

### When to Reboot

The new system becomes active after reboot. Reboot when convenient:
- ✅ After kids are done for the day
- ✅ Before they start playing
- ✅ Weekly as part of routine
- ✅ When you see update notification

**How to check if update is ready**:
```bash
# Compare current vs. available
readlink /nix/var/nix/profiles/system
readlink /run/current-system

# Different? Update is ready!
```

---

## 🛡️ Safety Features

### 1. No Auto-Reboot
```nix
allowReboot = false;  # CRITICAL for kids' laptop
```
**Why**: System will never interrupt:
- Minecraft games in progress
- File downloads
- Application sessions
- Anything the kids are doing

### 2. Bootloader Rollback
```
GRUB Boot Menu (hold Shift at boot):
  > NixOS 24.05 (2024-12-15)  ← Current
    NixOS 24.05 (2024-12-14)  ← Previous (if needed)
    NixOS 24.05 (2024-12-07)  ← Older versions...
```

If something breaks after update:
1. Reboot
2. Hold Shift to see boot menu
3. Select previous generation
4. System boots into old, working state

### 3. Automatic Garbage Collection
```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

**What this does**:
- Keeps last 30 days of system generations
- Automatically cleans up old packages
- Frees disk space
- Still keeps recent versions for rollback

### 4. Limited Boot Entries
```nix
boot.loader.systemd-boot.configurationLimit = 10;
```

**What this does**:
- Keeps last 10 generations in boot menu
- Prevents boot menu from getting cluttered
- Old generations still exist (for 30 days via gc)
- Can still roll back to recent versions

---

## 🔧 Manual Update Commands

### Apply Latest Configuration
```bash
# Pull latest from GitHub and rebuild
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#nix-kids-laptop
```

### Check for Updates Without Applying
```bash
# See what would change
sudo nixos-rebuild dry-build --flake /etc/nixos#nix-kids-laptop
```

### Update Flake Inputs
```bash
# Update nixpkgs and home-manager to latest in their branches
cd /etc/nixos
nix flake update
git add flake.lock
git commit -m "Update flake inputs"
git push
sudo nixos-rebuild switch --flake .#nix-kids-laptop
```

### List Generations
```bash
# See all system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Output:
# 1   2024-12-01 10:30:45
# 2   2024-12-07 03:00:12
# 3   2024-12-15 03:00:45   (current)
```

### Rollback to Previous Generation
```bash
# Go back one generation
sudo nixos-rebuild switch --rollback

# Or boot into it temporarily (reboot reverts)
sudo nixos-rebuild boot --rollback
sudo reboot
```

### Rollback to Specific Generation
```bash
# Switch to generation 2
sudo nix-env --switch-generation 2 --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

---

## 📊 Monitoring Updates

### Check Last Automatic Update
```bash
# View automatic update service logs
sudo journalctl -u nixos-upgrade.service

# View last run
sudo systemctl status nixos-upgrade.service
```

### Check Current Channel/Branch
```bash
# See what version you're tracking
nix flake metadata /etc/nixos

# Output shows:
# Inputs:
#   nixpkgs: github:nixos/nixpkgs/nixos-24.05
```

### Disk Space Usage
```bash
# See how much space Nix store uses
du -sh /nix/store

# Clean up immediately (don't wait for weekly gc)
sudo nix-collect-garbage --delete-older-than 30d

# Aggressive cleanup (remove everything not currently in use)
sudo nix-collect-garbage -d
```

---

## 🔐 Security Updates

### NixOS Security Model

**Stable Branch (nixos-24.05)**:
- Only security updates and critical bugfixes
- No feature changes
- Well-tested before release
- Updates come through regularly

**Your Configuration**:
- Pulls from `nixos-24.05` branch
- Gets security updates automatically
- Never gets surprise feature changes
- Stays stable and predictable

### How Fast Are Security Updates?

| Severity | Timeline |
|----------|----------|
| Critical (CVE) | Usually within 24-48 hours |
| High | Within a week |
| Medium | Within 2 weeks |
| Low | Regular update cycle |

**With automatic updates**: Your system gets these as soon as they're released

**Without**: You'd need to manually check and apply

---

## 🎮 Update Strategy for Kids' Laptop

### Recommended Routine

**Daily (Automatic)**:
- ✅ 3am: System checks for and builds updates
- ✅ No interruption to kids' activities
- ✅ Updates ready for next reboot

**Weekly (Manual)**:
- ✅ Sunday evening or Monday morning
- ✅ SSH in: `sudo reboot`
- ✅ System activates updates
- ✅ Kids login to updated, secure system

**Monthly (Manual)**:
- ✅ Check disk space: `df -h`
- ✅ Review generations: `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system`
- ✅ Verify OneDrive sync working
- ✅ Check system logs: `journalctl -p err -b`

---

## 🚨 Troubleshooting Updates

### Update Failed to Build
```bash
# Check what went wrong
sudo journalctl -u nixos-upgrade.service -n 100

# Common issues:
# - Network problem: Will retry next night
# - Syntax error in config: Fix in GitHub, will auto-pull
# - Disk full: Run garbage collection
```

### System Won't Boot After Update
```
1. Reboot and hold Shift
2. Select previous generation from menu
3. System boots into old version
4. SSH in and investigate:
   sudo journalctl -xb
5. Roll back permanently:
   sudo nixos-rebuild switch --rollback
```

### Out of Disk Space
```bash
# Emergency cleanup
sudo nix-collect-garbage -d
sudo nix-store --optimize

# This can free 10-50GB depending on history
```

### Update Takes Too Long
```bash
# Disable automatic updates temporarily
sudo systemctl stop nixos-upgrade.timer

# Re-enable later
sudo systemctl start nixos-upgrade.timer
```

---

## 📱 Remote Management

### SSH in to Check Status
```bash
# From your machine
ssh drew@nix-kids-laptop

# Check if update is ready
readlink /nix/var/nix/profiles/system
readlink /run/current-system
# Different? Update waiting

# Apply update
sudo reboot
```

### Schedule Reboot
```bash
# Reboot in 5 minutes (gives kids warning)
sudo shutdown -r +5 "System rebooting for updates in 5 minutes"

# Cancel if needed
sudo shutdown -c
```

### Remote Rollback
```bash
# If you hear "something broke after reboot"
ssh drew@nix-kids-laptop
sudo nixos-rebuild switch --rollback
# System immediately reverts to previous working state
```

---

## 🔄 Update Channels

### Current: Stable (Recommended)
```nix
nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
```
**Pros**: Stable, tested, predictable
**Cons**: Packages are 6 months behind latest

### Alternative: Unstable (Not Recommended for Kids)
```nix
nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
```
**Pros**: Latest packages, newest features
**Cons**: Less tested, can break, requires more maintenance

### When to Switch Channels

**Stay on 24.05 until**:
- NixOS 25.05 is released (May 2025)
- You've tested on VM first
- Kids' laptop is not mission-critical that week

**How to switch**:
```bash
# In flake.nix, change:
nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

# Then:
cd /etc/nixos
nix flake update
git add flake.nix flake.lock
git commit -m "Upgrade to NixOS 25.05"
git push
sudo nixos-rebuild switch --flake .#nix-kids-laptop
```

---

## 💡 Best Practices

### ✅ Do:
- Let automatic updates run nightly
- Reboot weekly to activate updates
- Keep at least 30 days of generations
- Test major changes on VM first
- Keep flake.lock in git

### ❌ Don't:
- Enable `allowReboot = true` (interrupts gaming)
- Delete all old generations (lose rollback)
- Ignore updates for months (security risk)
- Switch to unstable channel without reason
- Manually edit /etc/nixos files (use git)

---

## 📚 Learn More

- [NixOS Manual: Upgrading](https://nixos.org/manual/nixos/stable/#sec-upgrading)
- [Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [NixOS Discourse - Updates](https://discourse.nixos.org/c/help/8)

---

## 🎯 Summary

Your kids' laptop is configured with **automatic, safe updates**:

1. ✅ Updates download and build automatically (3am daily)
2. ✅ Never interrupts usage (no auto-reboot)
3. ✅ Always can roll back (10 generations, 30 days)
4. ✅ Cleans up automatically (weekly garbage collection)
5. ✅ Security updates applied regularly
6. ✅ You control when to reboot and activate

**Just reboot weekly**, and the system stays secure and up-to-date with zero maintenance!
