---
title: "Utility Belt"
description: "Main utilities hub with overview of all available utilities"
category: "general"
tags: ["overview", "navigation", "help"]
created: 2024-11-10
---

# Utility Belt

Overview of all available utilities and how to navigate them.

## Available Utilities

### System Utilities
- **proxmox-lxc-boot** - Initial boot for Proxmox LXC containers
- **docker-install** - Complete Docker installation script
- **rootless-docker** - Secure rootless Docker setup
- **rsync-backup** - Backup utilities using rsync

### Security & Networking
- **certificate-generation** - SSL certificate generation with Certbot

### NixOS
- **sops-nix-configuration** - Secret management with sops-nix

## Navigation Commands

Use the terminal commands to navigate and access utilities:

```bash
# List available directories
ls

# Navigate to utilities
cd utilities

# List utilities
ls

# Open a utility
cat utility-name

# Get help
help
```

## Quick Access

- **?** - Open keybinds cheat sheet
- **ESC** - Toggle terminal input focus
- **j/k** or **Arrow keys** - Navigate directory / scroll utilities
- **l** or **Enter** - Open selected item
- **Backspace** - Go back from utility view
- **y** - Yank (copy) focused code block
- **h/l** or **Arrow Left/Right** - Scroll focused code block horizontally

All utilities are designed to be practical, production-ready scripts that can be used directly in your projects.