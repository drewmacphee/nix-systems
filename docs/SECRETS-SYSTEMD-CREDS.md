# Secrets Management with systemd-creds

## Overview

This configuration uses a **hybrid approach** combining Azure Key Vault and systemd-creds for maximum security and convenience.

## Architecture

```
Azure Key Vault (Cloud)
         │
         │ ← Bootstrap fetches once
         ↓
systemd-creds (Local Encrypted Storage)
         │
         │ ← Decrypted on boot
         ↓
Runtime Files (~/.config, ~/.ssh, etc)
```

## How It Works

### 1. Bootstrap Phase (One-time)

When you run the bootstrap script:

1. **Azure Login**: You authenticate with Microsoft account + MFA
2. **Fetch Secrets**: Script downloads all secrets from Azure Key Vault:
   - User passwords
   - SSH authorized keys
   - OneDrive rclone configs
   - WiFi credentials
3. **Encrypt Locally**: Each secret is encrypted using `systemd-creds encrypt`:
   - Binds to TPM 2.0 chip (if available) or system-specific key
  - Stored in `/etc/credstore.encrypted/*.cred`
   - Cannot be decrypted on different hardware
  - Uses the host secret at `/var/lib/systemd/credential.secret` (created via `systemd-creds setup`)
4. **Cleanup**: Original plaintext secrets are securely deleted with `shred`

### 2. Boot Phase (Every restart)

On system boot, systemd services automatically:

1. **Decrypt Credentials**: Read encrypted `.cred` files
2. **Write to Runtime Locations**:
   - `~/.config/rclone/rclone.conf` - OneDrive access
   - `~/.ssh/authorized_keys` - SSH keys
3. **Set Permissions**: Correct ownership and file modes
4. **Service Ordering**: Ensures files exist before user login

### 3. Runtime (Normal Operation)

- Applications read decrypted secrets from standard locations
- No special handling needed by programs
- Secrets persist across reboots
- If hardware changes, credentials become unreadable (security feature)

## Security Benefits

| Aspect | Security Level | Why |
|--------|---------------|-----|
| **At Rest** | 🔐 Encrypted | TPM/hardware-bound encryption |
| **In Transit** | 🔐 TLS | Azure Key Vault uses HTTPS |
| **In Memory** | ⚠️ Plaintext | Standard for running applications |
| **Git Repository** | ✅ Not Stored | Never committed to source control |
| **Hardware Binding** | 🔐 TPM-bound | Can't copy to another machine |
| **Theft Protection** | 🔐 Strong | Encrypted credentials useless on other hardware |

## Comparison with Alternatives

### vs. Plaintext in /tmp

❌ **Old Approach** (plaintext):
- Secrets in `/tmp/nixos-secrets/`
- Readable by root
- Cleared on reboot (inconvenient)
- No encryption

✅ **systemd-creds** (encrypted):
- Encrypted at rest
- Hardware-bound
- Survives reboots
- Secure cleanup

### vs. sops-nix

**sops-nix**:
- ✅ Secrets in git (encrypted)
- ✅ Age/PGP encryption
- ❌ Requires key management
- ❌ Secrets committed to repo

**systemd-creds hybrid**:
- ✅ No secrets in git
- ✅ Hardware-bound encryption
- ✅ Simple key management (TPM)
- ✅ Azure Key Vault as source of truth

### vs. agenix

**agenix**:
- ✅ Age encryption
- ✅ Nix-integrated
- ❌ Secrets in git repo
- ❌ SSH key management

**systemd-creds hybrid**:
- ✅ No secrets in git
- ✅ Systemd-integrated
- ✅ TPM key management
- ✅ Cloud-based source

## How Secrets Are Used

### SSH Keys

```nix
systemd.services."decrypt-drew-ssh" = {
  description = "Decrypt drew-ssh-keys credential";
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = ''
      systemd-creds decrypt /etc/credstore.encrypted/drew-ssh-authorized-keys.cred \
        > /home/drew/.ssh/authorized_keys
      chmod 600 /home/drew/.ssh/authorized_keys
      chown drew:users /home/drew/.ssh/authorized_keys
    '';
  };
};
```

### OneDrive rclone

```nix
systemd.services."decrypt-drew-rclone" = {
  description = "Decrypt drew-rclone credential";
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = ''
      systemd-creds decrypt /etc/credstore.encrypted/drew-rclone.cred \
        > /home/drew/.config/rclone/rclone.conf
      chmod 600 /home/drew/.config/rclone/rclone.conf
      chown drew:users /home/drew/.config/rclone/rclone.conf
    '';
  };
};
```

### User Passwords

Set once during bootstrap (not decrypted on every boot):

```bash
DREW_PASS=$(systemd-creds decrypt "$CREDS_DIR/drew-password.cred" -)
echo "drew:$DREW_PASS" | chpasswd
```

## Disaster Recovery

### Scenario: Laptop Stolen

1. **Your secrets are safe**: Hardware-bound encryption means thief can't decrypt
2. **Revoke access**: Remove secrets from Azure Key Vault
3. **New laptop**: Bootstrap fetches fresh secrets, creates new encrypted credentials

### Scenario: Hard Drive Failure

1. **Replace drive**: Install NixOS minimal
2. **Run bootstrap**: Same curl command as before
3. **Automatic setup**: Fetches all secrets from Azure Key Vault
4. **New encrypted creds**: Created for new hardware

### Scenario: Lost Azure Access

⚠️ **Problem**: If you lose Azure access, you can't bootstrap new systems

**Mitigation**:
1. Keep local backup of decrypted secrets (encrypted separately)
2. Maintain access to Azure with proper MFA
3. Document Key Vault name and tenant ID

## Manual Operations

### View Encrypted Credential

```bash
sudo ls -lh /etc/credstore.encrypted
```

### Ensure Host Credential Secret Exists

```bash
sudo systemd-creds setup
sudo ls -lh /var/lib/systemd/credential.secret
```

### Decrypt Credential Manually

```bash
sudo systemd-creds decrypt /etc/credstore.encrypted/drew-rclone.cred -
```

### Re-encrypt After Update

If you update a secret in Azure Key Vault:

```bash
# Fetch new secret
az keyvault secret show --vault-name nix-kids-laptop --name drew-rclone-config --query value -o tsv > /tmp/new-secret

# Re-encrypt
sudo systemd-creds encrypt --name=drew-rclone /tmp/new-secret /etc/credstore.encrypted/drew-rclone.cred

# Cleanup
shred -u /tmp/new-secret

# Restart service to apply
sudo systemctl restart decrypt-drew-rclone
```

### Remove All Credentials (Fresh Start)

```bash
sudo rm -rf /etc/credstore.encrypted/*.cred
# Re-run bootstrap to fetch fresh from Azure
```

## Troubleshooting

### Credential won't decrypt

**Symptom**: `systemd-creds decrypt` fails with "Invalid argument"

**Causes**:
- Hardware changed (motherboard, TPM chip)
- Credential created on different system
- TPM sealed credential moved to new machine

**Solution**: Delete and re-create credentials via bootstrap

### Secrets not appearing at runtime

**Check service status**:
```bash
sudo systemctl status decrypt-drew-rclone
sudo systemctl status decrypt-drew-ssh
```

**Check logs**:
```bash
sudo journalctl -u decrypt-drew-rclone
```

**Verify credential exists**:
```bash
sudo ls -l /etc/credstore.encrypted/drew-rclone.cred
```

### Permission denied errors

**Ensure ownership is correct**:
```bash
ls -l /home/drew/.config/rclone/rclone.conf
# Should be: drew:users

ls -l /home/drew/.ssh/authorized_keys
# Should be: drew:users
```

## Best Practices

1. **Azure Key Vault**: Treat as source of truth
2. **Rotate Regularly**: Update secrets in Key Vault, then re-bootstrap
3. **Backup Strategy**: Keep access to Azure account secure
4. **Test Recovery**: Periodically test bootstrap on VM
5. **Monitor Access**: Review Azure Key Vault access logs
6. **MFA Always**: Require MFA for Azure access
7. **Document Recovery**: Keep recovery procedures up to date

## Why This Approach?

✅ **No Secrets in Git**: Repository is 100% public-safe  
✅ **Hardware Security**: TPM binding prevents credential theft  
✅ **Cloud Backup**: Azure Key Vault is your backup  
✅ **Easy Recovery**: One command restores everything  
✅ **No Key Management**: systemd/TPM handles keys automatically  
✅ **Survives Reboots**: Unlike /tmp-based approaches  
✅ **Standard Tools**: Uses systemd, no exotic dependencies  
✅ **Audit Trail**: Azure logs all secret access  

## Future Enhancements

Potential improvements:

1. **Auto-rotation**: Periodic secret refresh from Azure
2. **Secret version tracking**: Use Azure Key Vault versioning
3. **Per-host secrets**: Different credentials per machine
4. **Emergency access**: Fallback method if TPM fails
5. **Secret validation**: Health checks for decrypted secrets
