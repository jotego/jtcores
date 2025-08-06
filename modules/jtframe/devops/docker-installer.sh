#!/bin/bash

# This script will remove your existing Docker installation and
# will do a fresh Docker installation, including official plugins
# such as composer and buildx (required for building Jotego images).
# It will also set Docker in rootless mode so you won't need to use
# sudo, either interactively or within scripts.
# The script is architecture-independent.

set -e

echo "🚀 Docker installation on Ubuntu for Jotego devops..."

DOCKER_GPG_DIR="/etc/apt/keyrings"
DOCKER_GPG="$DOCKER_GPG_DIR/docker.gpg"
ARCH=$(dpkg --print-architecture)
RELEASE=$(lsb_release -cs)

# 1. Remove any existing Docker installation
echo "🔄 Removing old Docker versions..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get purge -y docker docker-engine docker.io containerd runc || true
sudo rm -rf /var/lib/docker /var/lib/containerd || true

# 2. Install dependencies
echo "📦 Installing dependencies..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release uidmap dbus-user-session

# 3. Add Docker GPG key and official repository
echo "🔑 Adding Docker GPG key..."
sudo install -m 0755 -d "$DOCKER_GPG_DIR"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o "$DOCKER_GPG"
sudo chmod a+r "$DOCKER_GPG"

echo "📄 Adding Docker repository..."
echo \
  "deb [arch=${ARCH} signed-by=${DOCKER_GPG}] https://download.docker.com/linux/ubuntu ${RELEASE} stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine and official plugins
echo "🐳 Installing Docker Engine and plugins..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Add current user to docker group (for rootful non-sudo usage)
echo "👤 Adding user to docker group..."
sudo usermod -aG docker "$USER"

# 6. Install rootless mode
echo "🔐 Setting up Docker rootless mode..."
dockerd-rootless-setuptool.sh install

# 7. Set rootless environment variables
echo "🧰 Setting up rootless environment..."

PROFILE_FILE="$HOME/.bashrc"
if [[ $SHELL == *zsh ]]; then
  PROFILE_FILE="$HOME/.zshrc"
fi

# Add environment variables only if not already present
grep -qxF 'export PATH=$HOME/bin:$PATH' "$PROFILE_FILE" || echo 'export PATH=$HOME/bin:$PATH' >> "$PROFILE_FILE"
grep -qxF 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' "$PROFILE_FILE" || echo 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' >> "$PROFILE_FILE"

echo ""
echo "✅ Docker installed successfully with rootless mode and buildx support."
echo "🔁 Please restart your terminal or run: source $PROFILE_FILE"
echo "🔍 Test it with: docker info"
echo ""