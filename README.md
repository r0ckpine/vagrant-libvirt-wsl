# Vagrant-libvirt on WSL

A demonstration of using the vagrant-libvirt plugin primarily on Windows Subsystem for Linux (WSL) environments, with support for general Linux systems.

## Overview

This project showcases how to set up and use Vagrant with libvirt virtualization, designed primarily for WSL environments but compatible with general Linux systems. It provides three different VM configurations for various development scenarios:

- **Minimal VM**: Basic testing environment
- **Kolla AIO**: Single-node OpenStack deployment (All-in-One)
- **Kolla Multi-node**: Multi-node OpenStack cluster (with controller and compute nodes)

## Prerequisites

### Windows Requirements
- Windows 11 with WSL2 enabled
- PowerShell access for WSL management

### Supported Linux Distributions
- **Tested WSL Distributions**:
  - `AlmaLinux OS 9`
  - `Ubuntu 24.04 LTS`

- **Other general Linux Distributions**:

  The playbook and scripts are designed to work with both RHEL and Debian variants.
  The following Linux distributions can be compatible:
  - **RHEL 9 variants**: AlmaLinux 9, Rocky Linux 9, CentOS Stream 9
  - **Ubuntu**: 24.04 or later

- **Required Packages**:
  - `ansible-core` for running ansible-playbook
  - `git` for cloning this repository

## Getting Started

### For WSL Users (Recommended Path)

#### 1. Install a WSL distribution
Open PowerShell and run:
```powershell
wsl.exe --install AlmaLinux-9
```
or
```powershell
wsl.exe --install Ubuntu-24.04
```

#### 2. Enable systemd in WSL
Before running any scripts, ensure systemd is enabled:
Add to /etc/wsl.conf (create if it doesn't exist)
```
[boot]
systemd=true
```
It seems that systemd is enabled by default in recent WSL and the distributions.
In that case, this step and the next step are not necessary.

#### 3. Restart WSL after enabling systemd.
From PowerShell:
```powershell
wsl.exe --shutdown
```
Then reopen your WSL session.

#### 4. Initial configuration
Copy and paste the contents of `initial-setup.sh` into your WSL terminal and run it.
- `initial-setup.sh` sets up passwordless sudo, performs package updates, and installs ansible-core and git.
- Skip this step if you already have passwordless sudo and ansible-core/git installed

#### 5. Clone this repository
```bash
git clone https://github.com/r0ckpine/vagrant-libvirt-wsl
cd vagrant-libvirt-wsl
```

#### 6. Install the virtualization stack using ansible-playbook
```bash
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml
```

#### 7. Set environment variable to configure Vagrant to use libvirt
Add this to your shell profile (`.bashrc`, `.zshrc`, etc.):
```bash
export VAGRANT_DEFAULT_PROVIDER="libvirt"
```

#### 8. Ensure your user belongs to the libvirt group
Check if your user is included in the libvirt group using the `groups` command.
If it's not included, please log out and log back in.

## Vagrantfile Configurations

### Minimal Development Environment
Perfect for basic testing and development:
```bash
cd vagrant/minimal
vagrant up
vagrant ssh
# When done:
vagrant destroy
```
**Resources**: 1 CPU, 2GB RAM, 20GB disk

### Single-Node OpenStack (Kolla AIO)
Complete OpenStack environment on a single VM:
```bash
cd vagrant/kolla-aio
vagrant up
vagrant ssh
# When done:
vagrant destroy
```
**Resources**: 8 CPU, 16GB RAM, 40GB disk

**Next Steps**: After `vagrant up` succeeds, proceed with OpenStack deployment using Kolla-Ansible. See the [kolla-ansible-demo](https://github.com/r0ckpine/kolla-ansible-demo) repository for detailed deployment instructions and playbooks.

### Multi-Node OpenStack Cluster
Production-like multi-node setup:
```bash
cd vagrant/kolla-multinode
vagrant up

# Access individual nodes
vagrant ssh controller
vagrant ssh compute1
vagrant ssh compute2

# Configure inter-node networking
./setup_vm_network.sh

# When done:
vagrant destroy
```

**Network Topology**:
- **Controller**: 10.0.2.10 (8 CPU, 16GB RAM, 40GB disk)
- **Compute1**: 10.0.2.11 (4 CPU, 8GB RAM, 40GB disk)
- **Compute2**: 10.0.2.12 (4 CPU, 8GB RAM, 40GB disk)
- **Network**: MTU 9000 for optimal performance

**Next Steps**: After `vagrant up` and `./setup_vm_network.sh` succeed, proceed with OpenStack deployment using Kolla-Ansible. See the [kolla-ansible-demo](https://github.com/r0ckpine/kolla-ansible-demo) repository for detailed multi-node deployment instructions and playbooks.

## Multi-Node Network Setup

The `setup_vm_network.sh` script automates inter-node connectivity:

1. **Host Resolution**: Updates `/etc/hosts` on all VMs
2. **SSH Keys**: Distributes SSH keys for passwordless access
3. **Cross-Node Access**: Enables direct SSH between any nodes

After running the script, you can SSH between nodes:
```bash
vagrant ssh controller -c 'ssh vagrant@compute1 hostname'
vagrant ssh compute1 -c 'ssh vagrant@compute2 hostname'
```

## Advanced Usage

### Selective Installation
Use Ansible tags to install specific components:
```bash
# Run prerequisite checks only
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml --tags prerequisites

# Install only Vagrant
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml --tags vagrant

# Install only libvirt
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml --tags libvirt

# Setup only vagrant-libvirt plugin
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml --tags vagrant-libvirt
```

### VM Performance Features
All configurations include:
- **CPU**: Host-passthrough mode with nested virtualization
- **Storage**: Virtio SCSI with writeback cache and discard support
- **Network**: Virtio networking with jumbo frames (MTU 9000)
- **Machine**: Q35 chipset for modern hardware support
- **Auto-resize**: Cloud-init disk expansion
- **Synced Folders**: Disabled for WSL compatibility

## What Gets Installed

### Linux Initialization (`initial-setup.sh`)
- Passwordless sudo configuration
- Package updates and core packages: ansible-core, git
- Supports both RHEL family and Ubuntu/Debian systems
- Can be skipped if passwordless sudo and ansible-core/git are already configured

### Ansible Automation (`setup-vagrant-libvirt.yml`)
- WSL systemd prerequisite checks (exits with instructions if not enabled)
- Enable and start NetworkManager (RHEL) or systemd-networkd (Ubuntu)
- Install Vagrant from HashiCorp's official repository
- Install libvirt virtualization stack and development tools
- Proper user permissions for libvirt
- Install vagrant-libvirt plugin

## Troubleshooting

### Common WSL Issues
- **KVM kernel modules**: Ensure the kernel module `kvm_intel` or `kvm_amd` is loaded
- **Environment Variable**: Ensure `VAGRANT_DEFAULT_PROVIDER="libvirt"` is set
- **SystemD**: Verify with `systemctl --version` after WSL restart
- **Permissions**:
  - Ensure the ownership of `/dev/kvm` is `root:kvm`
  - Check you're in the libvirt group: `groups`

### Libvirt Troubleshooting
```bash
# Check libvirt service
sudo systemctl status libvirtd

# Test libvirt connection
virsh list --all

# Verify default network
virsh net-list --all
```

### Vagrant Troubleshooting
```bash
# Verify installation
vagrant --version
vagrant plugin list

# Check provider
vagrant global-status

# Start with minimal config if issues occur
cd vagrant/minimal && vagrant up
```

## Project Structure

```
vagrant-libvirt-wsl/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── initial-setup.sh             # Linux initialization script
├── setup-vagrant-libvirt.yml    # Main Ansible playbook
├── inventory/
│   └── local                    # Localhost inventory
└── vagrant/
    ├── minimal/                 # Basic VM configuration
    │   └── Vagrantfile
    ├── kolla-aio/              # Single-node OpenStack
    │   └── Vagrantfile
    └── kolla-multinode/        # Multi-node OpenStack
        ├── Vagrantfile
        └── setup_vm_network.sh # Network automation script
```

## Contributing

This project demonstrates vagrant-libvirt capabilities and welcomes contributions:

- **Bug Reports**: Issues with specific OS versions or configurations
- **Improvements**: Enhancements to automation scripts
- **Documentation**: Better instructions or troubleshooting tips
- **Use Cases**: Share your OpenStack deployment experiences

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built for demonstrating vagrant-libvirt plugin capabilities
- Primarily designed for WSL environments but compatible with general Linux systems
- Tested on WSL with Ubuntu 24.04 and AlmaLinux 9
