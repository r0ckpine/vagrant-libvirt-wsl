#!/bin/bash

# Parse vagrant ssh-config output to extract host info and key files
parse_ssh_config() {
    vagrant ssh-config | awk '
    /^Host / { 
        host = $2 
    }
    /^  HostName / { 
        ip = $2
    }
    /^  IdentityFile / {
        identity_file = $2
        if (host != "" && ip != "" && identity_file != "") {
            print host ":" ip ":" identity_file
            host = ""
            ip = ""
            identity_file = ""
        }
    }'
}

# Update /etc/hosts file
update_hosts_file() {
    local vm_name=$1
    local hosts_entries="$2"
    
    echo "Updating /etc/hosts on $vm_name..."
    
    vagrant ssh $vm_name -c "
        sudo sed -i '/# vagrant-auto-hosts-start/,/# vagrant-auto-hosts-end/d' /etc/hosts
        echo '# vagrant-auto-hosts-start' | sudo tee -a /etc/hosts >/dev/null
        cat << 'EOF' | sudo tee -a /etc/hosts >/dev/null
$hosts_entries
EOF
        echo '# vagrant-auto-hosts-end' | sudo tee -a /etc/hosts >/dev/null
    " 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "  Successfully updated /etc/hosts on $vm_name"
    else
        echo "  Failed to update /etc/hosts on $vm_name"
    fi
}

# Setup SSH keys
setup_ssh_keys() {
    local vm_name=$1
    local all_public_keys="$2"
    
    echo "Setting up SSH keys for $vm_name..."
    
    vagrant ssh $vm_name -c "
        # Remove existing entries
        sed -i '/# vagrant-cross-access-start/,/# vagrant-cross-access-end/d' /home/vagrant/.ssh/authorized_keys
        
        # Add all public keys
        echo '# vagrant-cross-access-start' >> /home/vagrant/.ssh/authorized_keys
        cat << 'EOF' >> /home/vagrant/.ssh/authorized_keys
$all_public_keys
EOF
        echo '# vagrant-cross-access-end' >> /home/vagrant/.ssh/authorized_keys
        
        # Prepare SSH config
        mkdir -p /home/vagrant/.ssh/vm_keys
        sed -i '/# vagrant-vm-configs-start/,/# vagrant-vm-configs-end/d' /home/vagrant/.ssh/config 2>/dev/null || touch /home/vagrant/.ssh/config
        echo '# vagrant-vm-configs-start' >> /home/vagrant/.ssh/config
    " 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "  Successfully set up SSH keys for $vm_name"
    else
        echo "  Failed to set up SSH keys for $vm_name"
    fi
}

# Distribute identity files to a specific VM
distribute_identity_files_to_vm() {
    local source_host=$1
    shift
    local vm_configs=("$@")
    
    echo "Distributing identity files to $source_host..."
    
    # Create temporary SSH config
    local temp_ssh_config=$(mktemp)
    
    # Process each VM config
    for config in "${vm_configs[@]}"; do
        IFS=':' read -r target_host target_ip target_identity <<< "$config"
        
        if [ -f "$target_identity" ]; then
            echo "  Adding $target_host key to $source_host..."
            
            # Distribute private key
            vagrant ssh $source_host -c "
                cat > /home/vagrant/.ssh/vm_keys/${target_host}_key << 'EOF'
$(cat "$target_identity")
EOF
                chmod 600 /home/vagrant/.ssh/vm_keys/${target_host}_key
            " 2>/dev/null
            
            # Add SSH config entry
            cat >> "$temp_ssh_config" << EOF
Host $target_host
    HostName $target_ip
    User vagrant
    IdentityFile /home/vagrant/.ssh/vm_keys/${target_host}_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

EOF
        fi
    done
    
    # Add SSH config in batch
    if [ -s "$temp_ssh_config" ]; then
        vagrant ssh $source_host -c "
            cat >> /home/vagrant/.ssh/config << 'EOF'
$(cat "$temp_ssh_config")
EOF
            echo '# vagrant-vm-configs-end' >> /home/vagrant/.ssh/config
            chmod 600 /home/vagrant/.ssh/config
        " 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "  Successfully configured SSH for $source_host"
        else
            echo "  Failed to configure SSH for $source_host"
        fi
    fi
    
    rm -f "$temp_ssh_config"
}

# Collect all public keys
collect_all_public_keys() {
    local vm_configs=("$@")
    local temp_keys_file=$(mktemp)
    
    for config in "${vm_configs[@]}"; do
        IFS=':' read -r host ip identity_file <<< "$config"
        
        if [ -f "$identity_file" ]; then
            local public_key_file="${identity_file}.pub"
            if [ -f "$public_key_file" ]; then
                cat "$public_key_file" >> "$temp_keys_file"
            else
                ssh-keygen -y -f "$identity_file" >> "$temp_keys_file" 2>/dev/null
            fi
        fi
    done
    
    cat "$temp_keys_file"
    rm -f "$temp_keys_file"
}

# Main function
main() {
    echo "Vagrant VM Network Setup"
    echo "========================"
    
    echo "Parsing vagrant ssh-config..."
    local vm_configs_string=$(parse_ssh_config)
    
    if [ -z "$vm_configs_string" ]; then
        echo "ERROR: No VMs found in ssh-config"
        exit 1
    fi
    
    # Convert string to array
    IFS=$'\n' read -d '' -r -a vm_configs <<< "$vm_configs_string"
    
    echo "Found VMs:"
    for config in "${vm_configs[@]}"; do
        IFS=':' read -r host ip identity_file <<< "$config"
        echo "  $host: $ip"
    done
    
    # Generate /etc/hosts entries
    local hosts_entries=""
    for config in "${vm_configs[@]}"; do
        IFS=':' read -r host ip identity_file <<< "$config"
        hosts_entries="${hosts_entries}$ip $host"$'\n'
    done
    
    # Collect all public keys
    echo ""
    echo "Collecting public keys..."
    local all_public_keys=$(collect_all_public_keys "${vm_configs[@]}")
    
    if [ -z "$all_public_keys" ]; then
        echo "WARNING: No public keys found"
    else
        echo "Found $(echo "$all_public_keys" | wc -l) public keys"
    fi
    
    # Apply configuration to each VM
    echo ""
    echo "Configuring VMs..."
    for config in "${vm_configs[@]}"; do
        IFS=':' read -r host ip identity_file <<< "$config"
        echo ""
        echo "Processing VM: $host"
        update_hosts_file "$host" "$hosts_entries"
        setup_ssh_keys "$host" "$all_public_keys"
    done
    
    # Distribute identity files to each VM
    echo ""
    echo "Distributing identity files..."
    for config in "${vm_configs[@]}"; do
        IFS=':' read -r host ip identity_file <<< "$config"
        echo ""
        distribute_identity_files_to_vm "$host" "${vm_configs[@]}"
    done
    
    echo ""
    echo "Setup completed!"
    echo ""
    echo "You can now SSH between any VMs:"
    echo "  vagrant ssh <vm> -c 'ssh vagrant@<any_vm>'"
    echo ""
    echo "Example commands:"
    echo "  vagrant ssh controller -c 'ssh vagrant@controller hostname'"
    echo "  vagrant ssh controller -c 'ssh vagrant@compute1 hostname'"
    echo "  vagrant ssh compute1 -c 'ssh vagrant@compute2 hostname'"
}

main "$@"
