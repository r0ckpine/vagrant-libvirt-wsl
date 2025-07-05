#!/bin/bash

set -e

USERNAME=$(whoami)
SUDOERS_FILE="/etc/sudoers.d/wsl-${USERNAME}"

echo "Setting up passwordless sudo for user: $USERNAME"

# Create the sudoers drop-in file
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" > /dev/null

# Detect OS type
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_FAMILY=""
    case "$ID" in
        ubuntu|debian)
            OS_FAMILY="Debian"
            ;;
        rhel|centos|almalinux|rocky|fedora)
            OS_FAMILY="RedHat"
            ;;
        *)
            echo "Error: Unsupported OS: $ID"
            exit 1
            ;;
    esac
else
    echo "Error: Cannot detect OS type"
    exit 1
fi

echo "Detected OS family: $OS_FAMILY"

# Update system and install packages based on OS type
if [ "$OS_FAMILY" = "Debian" ]; then
    echo "Updating system (Ubuntu/Debian)..."
    sudo apt update
    sudo apt -y upgrade
    echo "Installing ansible-core and git..."
    sudo apt install -y ansible-core git
elif [ "$OS_FAMILY" = "RedHat" ]; then
    echo "Updating system (RHEL family)..."
    sudo dnf -y update
    echo "Installing ansible-core and git..."
    sudo dnf -y install ansible-core git
fi

echo "Initial setup completed."
