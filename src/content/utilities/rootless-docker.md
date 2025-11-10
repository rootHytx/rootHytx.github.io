---
title: "Rootless Docker Setup"
description: "Secure rootless Docker daemon setup for running containers without root privileges"
category: "docker"
tags: ["docker", "security", "rootless", "containers", "systemd"]
created: 2024-11-10
---

# Rootless Docker Setup

Rootless Docker allows running Docker daemon and containers as a non-root user, improving security by reducing the attack surface and container breakout risks.

## Installation Script

```bash
#!/bin/bash

# Install prerequisites
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker packages
sudo apt-get update
sudo apt install uidmap docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Disable root Docker service
sudo systemctl disable --now docker.service docker.socket
sudo rm /var/run/docker.sock

# Create dedicated user for rootless Docker
sudo groupadd --system docker
sudo useradd -m --system -g docker $TARGET_USER

# Set up rootless Docker
PATH=/usr/bin:$PATH
/usr/bin/dockerd-rootless-setuptool.sh install
```

## Setup Instructions

```bash
# 1. Replace $TARGET_USER with your desired username
# 2. Run the installation script
chmod +x rootless-docker-setup.sh
./rootless-docker-setup.sh

# 3. Add environment variables to your shell profile
echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
echo 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' >> ~/.bashrc
source ~/.bashrc

# 4. Start the rootless Docker service
systemctl --user start docker
systemctl --user enable docker

# 5. Verify installation
docker --version
docker run hello-world
```

## Service Management

```bash
# Start rootless Docker service
systemctl --user start docker

# Stop rootless Docker service
systemctl --user stop docker

# Check service status
systemctl --user status docker

# Enable auto-start on boot
systemctl --user enable docker
loginctl enable-linger $USER
```

## Limitations & Considerations

### Port Binding Limitations
- Can only bind to ports >= 1024
- Use port forwarding for privileged ports

### Network Limitations
- Some network drivers may not work
- Host networking is restricted

### Storage Limitations
- Some storage drivers may not be available
- FUSE overlayfs is used by default

### Performance
- Slightly reduced performance due to user namespace
- Additional overhead for system calls

## Troubleshooting

```bash
# Check if rootless mode is active
docker info | grep -i rootless

# Check user namespace support
cat /proc/sys/kernel/unprivileged_userns_clone

# Enable user namespaces if disabled
echo 'kernel.unprivileged_userns_clone=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Fix permission issues
sudo setcap cap_net_bind_service=ep $(which rootlesskit)
```

## Security Benefits

- **Reduced attack surface** - No root privileges required
- **User namespace isolation** - Enhanced container security
- **Container breakout protection** - Limits damage from container escapes
- **Better multi-user security** - Each user has isolated Docker instances
- **Compliance with security policies** - Meets strict security requirements

## Port Forwarding for Privileged Ports

```bash
# Forward port 80 to 8080 for web applications
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

# Or use socat for simple forwarding
socat TCP-LISTEN:80,fork TCP:localhost:8080
```

## Systemd User Service

Create `~/.config/systemd/user/docker.service`:

```ini
[Unit]
Description=Docker Application Container Engine (Rootless)
Documentation=https://docs.docker.com

[Service]
Type=notify
ExecStart=/usr/bin/dockerd-rootless.sh
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes

[Install]
WantedBy=default.target
```

## Best Practices

- Use rootless mode for development and testing
- Consider rootless for production with proper security review
- Monitor resource usage as rootless has higher overhead
- Use volume mounts instead of bind mounts when possible
- Keep the system updated with security patches

## Migration from Root Docker

```bash
# Stop root Docker
sudo systemctl stop docker

# Export containers and images
docker save -o containers.tar $(docker images -q)

# Start rootless Docker
systemctl --user start docker

# Import containers and images
docker load -i containers.tar
```
