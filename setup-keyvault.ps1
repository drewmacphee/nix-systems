# Azure Key Vault Setup Script
# Run this script to populate your Key Vault with all required secrets

Write-Host "========================================"
Write-Host "Azure Key Vault Setup"
Write-Host "========================================"
Write-Host ""

$vaultName = "nix-kids-laptop"

# Check if Azure CLI is available
try {
    az account show 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Not logged in to Azure. Please login first:" -ForegroundColor Yellow
        Write-Host "  az login" -ForegroundColor Cyan
        exit 1
    }
} catch {
    Write-Host "Azure CLI not found or not working. Please install or fix Azure CLI." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Logged in to Azure" -ForegroundColor Green
Write-Host ""

# Function to prompt for file and upload
function Upload-Secret {
    param(
        [string]$SecretName,
        [string]$Description,
        [string]$Instructions = ""
    )
    
    Write-Host "==== $SecretName ====" -ForegroundColor Cyan
    Write-Host $Description
    if ($Instructions) {
        Write-Host $Instructions -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Check if secret already exists
    $existing = az keyvault secret show --vault-name $vaultName --name $SecretName 2>$null
    if ($LASTEXITCODE -eq 0) {
        $response = Read-Host "Secret '$SecretName' already exists. Overwrite? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Skipping $SecretName" -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    }
    
    # Prompt for file path
    $filePath = Read-Host "Enter path to file (or 'skip' to skip)"
    
    if ($filePath -eq 'skip') {
        Write-Host "Skipped $SecretName" -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    if (-not (Test-Path $filePath)) {
        Write-Host "File not found: $filePath" -ForegroundColor Red
        Write-Host ""
        return $false
    }
    
    # Upload to Key Vault
    Write-Host "Uploading to Key Vault..." -ForegroundColor Yellow
    az keyvault secret set --vault-name $vaultName --name $SecretName --file $filePath 2>$null | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully uploaded $SecretName" -ForegroundColor Green
        Write-Host ""
        return $true
    } else {
        Write-Host "✗ Failed to upload $SecretName" -ForegroundColor Red
        Write-Host ""
        return $false
    }
}

# Track what was uploaded
$uploaded = @()
$skipped = @()

# SSH Keys for Drew
if (Upload-Secret `
    -SecretName "drew-ssh-authorized-keys" `
    -Description "SSH public key(s) for Drew to enable remote access" `
    -Instructions "Typically ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub") {
    $uploaded += "drew-ssh-authorized-keys"
} else {
    $skipped += "drew-ssh-authorized-keys"
}

# SSH Keys for Emily
if (Upload-Secret `
    -SecretName "emily-ssh-authorized-keys" `
    -Description "SSH public key(s) for Emily" `
    -Instructions "Same as Drew's or different keys if needed") {
    $uploaded += "emily-ssh-authorized-keys"
} else {
    $skipped += "emily-ssh-authorized-keys"
}

# SSH Keys for Bella
if (Upload-Secret `
    -SecretName "bella-ssh-authorized-keys" `
    -Description "SSH public key(s) for Bella" `
    -Instructions "Same as Drew's or different keys if needed") {
    $uploaded += "bella-ssh-authorized-keys"
} else {
    $skipped += "bella-ssh-authorized-keys"
}

# Drew's rclone config
Write-Host ""
Write-Host "NOTE: For rclone configs, you need to run 'rclone config' first!" -ForegroundColor Yellow
Write-Host "See ONEDRIVE-SETUP.md for detailed instructions." -ForegroundColor Yellow
Write-Host ""

if (Upload-Secret `
    -SecretName "drew-rclone-config" `
    -Description "Drew's OneDrive rclone configuration (drewjamesross@outlook.com)" `
    -Instructions "After running 'rclone config', file is at: ~/.config/rclone/rclone.conf (Linux) or %APPDATA%\rclone\rclone.conf (Windows)") {
    $uploaded += "drew-rclone-config"
} else {
    $skipped += "drew-rclone-config"
}

# Emily's rclone config
if (Upload-Secret `
    -SecretName "emily-rclone-config" `
    -Description "Emily's OneDrive rclone configuration (emilykamacphee@outlook.com)" `
    -Instructions "Remember to clear old config first: rm ~/.config/rclone/rclone.conf") {
    $uploaded += "emily-rclone-config"
} else {
    $skipped += "emily-rclone-config"
}

# Bella's rclone config
if (Upload-Secret `
    -SecretName "bella-rclone-config" `
    -Description "Bella's OneDrive rclone configuration (isabellaleblanc@outlook.com)" `
    -Instructions "Remember to clear old config first: rm ~/.config/rclone/rclone.conf") {
    $uploaded += "bella-rclone-config"
} else {
    $skipped += "bella-rclone-config"
}

# Summary
Write-Host ""
Write-Host "========================================"
Write-Host "Setup Complete!"
Write-Host "========================================"
Write-Host ""

if ($uploaded.Count -gt 0) {
    Write-Host "✓ Uploaded ($($uploaded.Count)):" -ForegroundColor Green
    foreach ($item in $uploaded) {
        Write-Host "  - $item" -ForegroundColor Green
    }
    Write-Host ""
}

if ($skipped.Count -gt 0) {
    Write-Host "⚠ Skipped ($($skipped.Count)):" -ForegroundColor Yellow
    foreach ($item in $skipped) {
        Write-Host "  - $item" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Verify all secrets
Write-Host "Verifying Key Vault contents..." -ForegroundColor Cyan
$secrets = az keyvault secret list --vault-name $vaultName --query "[].name" -o tsv
Write-Host ""
Write-Host "Current secrets in Key Vault:" -ForegroundColor Cyan
foreach ($secret in $secrets) {
    Write-Host "  ✓ $secret" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Ensure all 6 secrets are uploaded (3 SSH keys + 3 rclone configs)"
Write-Host "2. Push your config to GitHub"
Write-Host "3. Run bootstrap script on target NixOS system"
Write-Host ""
Write-Host "To re-run this script: ./setup-keyvault.ps1" -ForegroundColor Gray
