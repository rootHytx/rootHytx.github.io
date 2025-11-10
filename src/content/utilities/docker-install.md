---
title: "Docker Installation"
description: "Complete Docker installation script for Ubuntu systems from official repositories"
category: "docker"
tags: ["docker", "installation", "ubuntu", "containers"]
created: 2024-11-10
---

# Docker Installation Script

Complete Docker installation script for Ubuntu systems. This script installs the latest Docker Engine from Docker's official repositories.

## Installation Script

```bash
#!/bin/bash

# Remove old Docker versions
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove $pkg
done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Post-Installation Steps

```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Activate group changes (log out and back in, or run:)
newgrp docker

# Verify installation
docker --version
docker compose version

# Test Docker
docker run hello-world
```

## Usage Notes

```bash
# Save the script as install-docker.sh
chmod +x install-docker.sh
./install-docker.sh

# Or run directly:
curl -fsSL https://get.docker.com | sh

# Warning: The script removes existing Docker installations
# Make sure to backup any important containers/data
```

## Alternative: One-Line Install

```bash
# Use Docker's official install script:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Or direct pipe:
curl -fsSL https://get.docker.com | sh
```

## Uninstall Docker

```bash
# Remove Docker packages
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Remove images, containers, and volumes
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

## Docker Compose Setup

```bash
# Install Docker Compose (if not included)
sudo apt-get install docker-compose-plugin

# Verify Docker Compose
docker compose version

# Create docker-compose.yml file
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
EOF

# Run with Docker Compose
docker compose up -d
```

## Common Issues

### Permission Denied
```bash
# If you get "Got permission denied" error:
sudo usermod -aG docker $USER
newgrp docker
```

### Port Already in Use
```bash
# Check what's using the port
sudo netstat -tulpn | grep :80

# Or use lsof
sudo lsof -i :80
```

### Docker Daemon Not Running
```bash
# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

## Production Considerations

- Use specific Docker versions in production
- Set up logging and monitoring
- Configure resource limits
- Implement security best practices
- Use Docker in rootless mode when possible
- Set up automated updates and backups
