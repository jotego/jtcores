#!/bin/bash -e

# This script will remove your existing Docker installation and
# will do a fresh Docker installation, including official plugins
# such as composer and buildx (required for building Jotego images).
# It will also set Docker in rootless mode so you won't need to use
# sudo, either interactively or within scripts.
# The script is architecture-independent.

DOCKER_GPG_DIR="/etc/apt/keyrings"
DOCKER_GPG="$DOCKER_GPG_DIR/docker.gpg"
ARCH=$(dpkg --print-architecture)
RELEASE=$(lsb_release -cs)

main() {
  echo ""
  echo "Docker installation on Ubuntu for Jotego devops"
  echo ""

  remove_docker
  install_dependencies
  add_docker_repo
  install_docker
  set_rootless

  echo ""
  echo "Docker installed successfully with rootless mode and buildx support."
  echo "Please restart your terminal or run: source $PROFILE_FILE"
  echo "Test it with: docker info"
  echo ""
}

remove_docker() {
  echo "Removing old Docker versions"
  sudo apt-get remove --yes docker docker-engine docker.io containerd runc || true
  sudo apt-get purge --yes docker docker-engine docker.io containerd runc || true
  sudo rm -rf /var/lib/docker /var/lib/containerd || true
}

install_dependencies() {
  echo "Installing dependencies"
  sudo apt-get update
  sudo apt-get install --yes ca-certificates curl gnupg lsb-release uidmap dbus-user-session
}

add_docker_repo() {
  echo "Adding Docker GPG key"
  sudo install -m 0755 -d "$DOCKER_GPG_DIR"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o "$DOCKER_GPG"
  sudo chmod a+r "$DOCKER_GPG"

  echo "Adding Docker repository"
  echo \
    "deb [arch=${ARCH} signed-by=${DOCKER_GPG}] https://download.docker.com/linux/ubuntu ${RELEASE} stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

install_docker() {
  echo "Installing Docker Engine and plugins"
  sudo apt-get update
  sudo apt-get install --yes docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

set_rootless() {
  echo "Adding user to docker group"
  sudo usermod -aG docker "$USER"

  echo "Setting up Docker rootless mode"
  dockerd-rootless-setuptool.sh install

  echo "Setting up rootless environment"

  PROFILE_FILE="$HOME/.bashrc"
  if [[ $SHELL == *zsh ]]; then
    PROFILE_FILE="$HOME/.zshrc"
  fi

  grep -qxF 'export PATH=$HOME/bin:$PATH' "$PROFILE_FILE" ||
  echo 'export PATH=$HOME/bin:$PATH' >> "$PROFILE_FILE"

  grep -qxF 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' "$PROFILE_FILE" ||
  echo 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' >> "$PROFILE_FILE"
}

main