# Minecraft LAN Server Discovery Guide

This configuration enables Minecraft LAN server discovery on your local network.

## What's Configured

### 1. Hostname
- **Hostname**: `nix-kids-laptop`
- Shows up in network browser and Minecraft server lists

### 2. mDNS/Avahi (Bonjour)
Enables automatic service discovery on local network:
```nix
services.avahi = {
  enable = true;
  nssmdns4 = true;           # Enable mDNS in NSS
  publish = {
    enable = true;
    addresses = true;         # Publish IP addresses
    workstation = true;       # Publish workstation type
  };
};
```

**What this does:**
- Allows `nix-kids-laptop.local` to resolve without DNS
- Enables LAN service discovery
- Required for Minecraft LAN multiplayer detection

### 3. Firewall Rules

**TCP Ports:**
- `22` - SSH for remote access
- `25565` - Minecraft server (default port)

**UDP Ports:**
- `5353` - mDNS (multicast DNS for .local resolution)
- `24454` - Minecraft LAN world announcements

```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 25565 ];
  allowedUDPPorts = [ 5353 24454 ];
};
```

## How Minecraft LAN Discovery Works

1. **Host opens world to LAN** (in Minecraft: Esc → Open to LAN)
2. **Minecraft broadcasts** UDP packets on port 24454
3. **Other players' Minecraft** listens on port 24454
4. **Multiplayer menu** shows discovered LAN worlds automatically

## Testing LAN Discovery

### Test mDNS Resolution
```bash
# From another Linux/Mac machine
ping nix-kids-laptop.local

# Should show response from the laptop
```

### Test Minecraft LAN
1. **On nix-kids-laptop**: Open a Minecraft world, press Esc → "Open to LAN"
2. **On another device**: Open Minecraft → Multiplayer
3. **Should see**: "LAN World - {world name}" appear automatically

### Check Avahi Status
```bash
# On the laptop
systemctl status avahi-daemon

# List services being announced
avahi-browse -a
```

## Troubleshooting

### LAN Worlds Don't Appear

**1. Check firewall:**
```bash
sudo nix-shell -p nmap --run "sudo nmap -sU -p 24454 localhost"
```
Should show port 24454 as open.

**2. Check Avahi:**
```bash
systemctl status avahi-daemon
```
Should be "active (running)".

**3. Verify network is trusted:**
- NetworkManager should have the WiFi/Ethernet marked as "Home" or "Trusted"
- Check with: `nmcli connection show`

**4. Check Java network stack:**
Sometimes Minecraft's Java network stack has issues. Try:
- Restart Minecraft
- Ensure all players are on same network segment
- Check router doesn't block UDP broadcasts

### Can't Connect to LAN Server

If you see the LAN world but can't connect:

**1. Check Minecraft server port:**
When opening to LAN, Minecraft shows: "Local game hosted on port XXXXX"
That port must be opened in firewall.

**2. Add dynamic port range:**
Minecraft uses random ports for LAN servers. You can:

```nix
# In configuration.nix
networking.firewall = {
  allowedTCPPortRanges = [
    { from = 25565; to = 25575; }  # Minecraft LAN port range
  ];
};
```

**3. Check IP address:**
```bash
ip addr show
```
Ensure you're on same subnet (e.g., both 192.168.1.x)

### mDNS Not Working

**1. Check nssmdns:**
```bash
cat /etc/nsswitch.conf | grep hosts
```
Should include: `hosts: files mymachines mDNS_MINIMAL [NOTFOUND=return] dns`

**2. Test mDNS resolution:**
```bash
avahi-resolve -n nix-kids-laptop.local
```

## Network Security Notes

**LAN discovery requires:**
- UDP broadcasts (can't be fully firewalled)
- mDNS on port 5353
- Same network segment

**If you're concerned about security:**
- These ports only allow LAN discovery/connection
- No external internet exposure
- Router firewall protects from WAN
- Can disable when not gaming:
  ```bash
  sudo systemctl stop avahi-daemon
  ```

## Alternative: Direct Connect

If LAN discovery doesn't work, players can direct connect:

1. **Host** finds their IP: `ip addr show | grep inet`
2. **Player** in Minecraft: Multiplayer → Direct Connect
3. **Enter**: `192.168.1.XX:25565` (host's IP + port shown when opening to LAN)

## Advanced: Hosting Dedicated Server

For a always-on Minecraft server (not just LAN):

```nix
# In configuration.nix
services.minecraft-server = {
  enable = true;
  eula = true;
  declarative = true;
  
  serverProperties = {
    server-port = 25565;
    gamemode = "survival";
    difficulty = "normal";
    max-players = 10;
    motd = "Kids Laptop Minecraft Server";
  };
};
```

This runs a dedicated Minecraft server that:
- Starts automatically on boot
- Runs in background
- Accessible even when no one logged in
- Uses proper server software (better performance)

## Minecraft Versions

**Java Edition** (PrismLauncher):
- ✅ LAN discovery works out of the box
- ✅ Uses UDP port 24454
- ✅ Works on PC, Mac, Linux

**Bedrock Edition**:
- Different LAN discovery protocol
- Uses different ports (19132-19133 UDP)
- Not configured by default (Java focus)

To add Bedrock support:
```nix
networking.firewall.allowedUDPPorts = [ 19132 19133 ];
```

## Summary

✅ **Configured:** mDNS (Avahi) for LAN discovery  
✅ **Configured:** Firewall rules for Minecraft LAN  
✅ **Configured:** Hostname `nix-kids-laptop`  
✅ **Working:** LAN worlds should appear automatically in Multiplayer menu  

If issues persist, try direct connect as fallback!
