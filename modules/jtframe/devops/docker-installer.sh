#!/bin/bash -e

# This script will remove your existing Docker installation and
# will do a fresh Docker installation, including official plugins
# such as composer and buildx (required for building Jotego images).
# It will also set Docker in rootless mode so you won't need to use
# sudo, either interactively or within scripts.
# The script is architecture-independent.

# Warning: --network=host is likely to not work in Docker rootless mode.
# Use bridge networking or run Docker with root privileges if host networking is required.

DOCKER_GPG_DIR="/etc/apt/keyrings"
DOCKER_GPG="$DOCKER_GPG_DIR/docker.gpg"
ARCH=$(dpkg --print-architecture)
RELEASE=$(lsb_release -cs)

main() {
  echo ""
  echo " --- Docker installation on Ubuntu for Jotego devops --- "
  echo ""

  remove_docker
  install_dependencies
  add_docker_repo
  install_docker
  set_rootless

  echo ""
  echo "[INFO] Docker installed successfully with rootless mode and buildx support."
  echo "[INFO] Please restart your terminal or run: source $PROFILE_FILE"
  echo "[INFO] Test it with: docker info"
  echo ""
}

remove_docker() {
  if [ -d "/var/lib/docker" ]; then
    echo "[WARNING] Docker rootful data detected at /var/lib/docker."
    echo "If you switch to Docker rootless, existing containers, images and volumes WILL BE REMOVED."
    echo "Consider exporting them or keeping rootful Docker active."
    read -p "Continue with rootless setup? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
      echo "Aborting setup."
      exit 1
    fi
  fi

  echo "[INFO] Stopping and disabling Docker services if running"
  sudo systemctl stop docker.service docker.socket containerd.service || true
  sudo systemctl disable docker.service docker.socket containerd.service || true
  sudo systemctl reset-failed docker.service docker.socket containerd.service || true

  echo "[INFO] Removing old Docker packages"
  sudo apt-get remove --yes docker docker-engine docker.io containerd runc || true
  sudo apt-get purge --yes docker docker-engine docker.io containerd runc || true

  echo "[INFO] Removing Docker data directories"
  sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker || true
  sudo rm -f /var/run/docker.sock || true

  echo "[INFO] Docker removal complete."
}

install_dependencies() {
  echo "[INFO] Installing dependencies"
  sudo apt-get update
  sudo apt-get install --yes ca-certificates curl gnupg lsb-release uidmap dbus-user-session
}

add_docker_repo() {
  echo "[INFO] Checking for Docker GPG key and repository"

  if [ ! -f "$DOCKER_GPG" ]; then
    echo "[INFO] Adding Docker GPG key"
    sudo install -m 0755 -d "$(dirname "$DOCKER_GPG")"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o "$DOCKER_GPG"
    sudo chmod a+r "$DOCKER_GPG"
  else
    echo "[INFO] Docker GPG key already exists, skipping"
  fi

  if grep -q "^deb .*download.docker.com" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
    echo "[INFO] Docker repository already present, skipping"
  else
    echo "[INFO] Adding Docker repository"
    echo "deb [arch=${ARCH} signed-by=${DOCKER_GPG}] https://download.docker.com/linux/ubuntu ${RELEASE} stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi
}

install_docker() {
  echo "[INFO] Installing Docker Engine and plugins"
  sudo apt-get update
  sudo apt-get install --yes docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

set_rootless() {
  echo "[INFO] Adding user to docker group"
  sudo usermod -aG docker "$USER"

  echo "[INFO] Setting up Docker rootless mode"
  dockerd-rootless-setuptool.sh install

  echo "[INFO] Setting up rootless environment"

  PROFILE_FILE="$HOME/.bashrc"
  if [[ $SHELL == *zsh ]]; then
    PROFILE_FILE="$HOME/.zshrc"
  fi

  grep -qxF 'export PATH=$HOME/bin:$PATH' "$PROFILE_FILE" ||
  echo 'export PATH=$HOME/bin:$PATH' >> "$PROFILE_FILE"

  grep -qxF "export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock" "$PROFILE_FILE" ||
  echo "export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock" >> "$PROFILE_FILE"
}

main