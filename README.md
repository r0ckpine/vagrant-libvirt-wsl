# Vagrant-libvirt on WSL

A demonstration of using the vagrant-libvirt plugin on WSL environments, with infrastructure automation for OpenStack development. While primarily designed for WSL, it also works on general Linux environments.

## Overview

This project showcases how to set up and use Vagrant with libvirt virtualization on Windows Subsystem for Linux (WSL), providing three different VM configurations for various OpenStack development scenarios:

- **Minimal VM**: Basic testing environment
- **Kolla AIO**: Single-node OpenStack deployment (All-in-One)
- **Kolla Multi-node**: Multi-node OpenStack cluster (with controller and compute nodes)

## Prerequisites

### Operating System Support
- **Primary**: WSL with AlmaLinux 9 (tested configuration)
- **General Linux**: RHEL 9 variants (AlmaLinux 9, Rocky Linux 9, CentOS Stream 9)
- **Required**: ansible-core RPM package

### Windows Requirements
- Windows with WSL2 enabled
- PowerShell access for WSL management

## Getting Started

### For WSL Users (Recommended Path)

#### 1. Install WSL AlmaLinux 9
Open PowerShell as Administrator and run:
```powershell
wsl.exe --install AlmaLinux-9
```

#### 2. Initial WSL Configuration
In your new AlmaLinux WSL environment:
```bash
# Clone this repository
git clone https://github.com/r0ckpine/vagrant-libvirt-wsl
cd vagrant-libvirt-wsl

# Run the initialization script
./initial-setup-on-wsl.sh
```
> **Note**: You can also copy and paste the script content directly into your terminal

#### 3. Restart WSL
From PowerShell:
```powershell
wsl.exe --shutdown
```
Then reopen your AlmaLinux WSL session.

#### 4. Install Virtualization Stack
```bash
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml
```

#### 5. Configure Vagrant for WSL
Add this to your shell profile (`.bashrc`, `.zshrc`, etc.):
```bash
export VAGRANT_DEFAULT_PROVIDER="libvirt"
```

Optionally, if you want to use Vagrant with Hyper-V/VirtualBox provider,
also add the following variable to access from the WSL environments.
```bash
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
```

### For General Linux Users

If you're on a RHEL 9 variant with ansible-core already available:
```bash
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml
```

## VM Configurations

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
# Install only libvirt
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml --tags libvirt

# Install only Vagrant
ansible-playbook -i inventory/local setup-vagrant-libvirt.yml --tags vagrant

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

### WSL Initialization (`initial-setup-on-wsl.sh`)
- SystemD (required for libvirt on WSL)
- Passwordless sudo configuration
- Core packages: ansible-core, git

### Ansible Automation (`setup-vagrant-libvirt.yml`)
- Complete libvirt virtualization stack with NetworkManager
- Vagrant from HashiCorp's official repository
- vagrant-libvirt plugin with all dependencies
- NetworkManager and libvirtd service configuration
- Development tools and utilities
- Proper user permissions for libvirt

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
├── CLAUDE.md                    # AI assistant guidance
├── initial-setup-on-wsl.sh      # WSL initialization script
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
- Optimized for OpenStack development workflows
- Tested primarily on WSL AlmaLinux 9 environments

