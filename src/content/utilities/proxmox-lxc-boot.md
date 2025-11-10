---
title: "Proxmox LXC Initial Boot"
description: "Automated Proxmox LXC container creation with Ubuntu 24.04 and Tailscale VPN setup"
category: "system"
tags: ["proxmox", "lxc", "tailscale", "ubuntu", "automation"]
created: 2024-11-10
---

# Proxmox LXC Initial Boot Script

This script automates the creation and initial setup of a Proxmox LXC container with Ubuntu 24.04, including Tailscale VPN setup for secure remote access.

## Script

```bash
#!/bin/bash

# Generate next available container ID
nextid=$(ls /etc/pve/lxc/*.conf 2>/dev/null | \
         sed 's/.*\///;s/\.conf//' | \
         sort -n | tail -n1 | \
         awk '{print $1+1}')
last_digit="${nextid: -1}"
ctname="ctfd-${last_digit}"
ctt="local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
cts="local-lvm"

# Container specifications
memory=1024
swap=2048
storage_space=20

# Create the container
pct create ${nextid} ${ctt} \
  --hostname=${ctname} \
  --nameserver=1.1.1.1 \
  --searchdomain=1.0.0.1 \
  --password=${ctname} \
  --ostype=ubuntu --unprivileged=0 --features nesting=1 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --arch=amd64 --swap=${swap} --memory=${memory} \
  --storage=${cts}

# Resize storage and start container
pct resize ${nextid} rootfs +$((storage_space-4))G
pct start ${nextid}
pct enter ${nextid}

# Update system and install Tailscale
apt-get update && apt-get upgrade -y
apt-get install curl -y
curl -fsSL https://tailscale.com/install.sh | sh
systemctl start tailscaled
tailscale up
```

## Usage Notes

```bash
# Run as root on Proxmox host
bash proxmox-lxc-boot.sh
```

### What the script does:
- Finds the next available container ID automatically
- Creates Ubuntu 24.04 LXC container with specified resources
- Configures network with DHCP and custom nameservers
- Sets up storage with specified space allocation
- Installs and configures Tailscale VPN for secure remote access
- Container password is automatically set to container name

### Features:
- **Automatic ID generation** - No manual container ID management
- **Ubuntu 24.04** - Latest stable Ubuntu LTS
- **Tailscale integration** - Secure mesh VPN out of the box
- **Resource optimization** - Balanced memory, swap, and storage
- **Nesting enabled** - Allows running Docker inside LXC

### Prerequisites:
- Proxmox VE installed and configured
- Network bridge (vmbr0) configured
- Storage (local-lvm) available
- Root access on Proxmox host

### Customization:
- Modify `memory`, `swap`, and `storage_space` variables as needed
- Change `ctname` pattern for different naming conventions
- Adjust network bridge if using different network configuration