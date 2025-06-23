#!/bin/bash

set -e

# Check if running on WSL
if ! [[ -n "$WSL_DISTRO_NAME" ]] && ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo "Error: This script is designed for WSL environments only"
    exit 1
fi

echo "Enabling systemd on WSL"
sudo bash -c 'cat > /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF'

USERNAME=$(whoami)
SUDOERS_FILE="/etc/sudoers.d/wsl-${USERNAME}"

echo "Setting up passwordless sudo for user: $USERNAME"

# Create the sudoers drop-in file
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" > /dev/null

echo "Updating system..."
sudo dnf -y update

echo "Installing ansible-core and git..."
sudo dnf -y install ansible-core git

echo "Initial setup completed. Please terminate and restart the WSL session to apply systemd setting."
