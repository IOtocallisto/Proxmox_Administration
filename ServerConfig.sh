#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_message "Error: This script must be run as root"
        exit 1
    fi
}

# Function to generate a new machine ID
reset_machine_id() {
    log_message "Regenerating machine-id..."
    rm -f /etc/machine-id
    rm -f /var/lib/dbus/machine-id
    dbus-uuidgen --ensure=/etc/machine-id
    dbus-uuidgen --ensure=/var/lib/dbus/machine-id
}

# Function to reset SSH host keys
reset_ssh_keys() {
    log_message "Regenerating SSH host keys..."
    rm -f /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server
}

# Function to clean network configuration
reset_network() {
    log_message "Resetting network configuration..."
    # Backup original network configuration
    if [ -f /etc/netplan/00-installer-config.yaml ]; then
        cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak
    fi
    
    # Remove persistent network rules
    rm -f /etc/udev/rules.d/70-persistent-net.rules
}

# Function to clean system logs
clean_logs() {
    log_message "Cleaning system logs..."
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
    find /var/log -type f -name "*.gz" -delete
    > /var/log/wtmp
    > /var/log/btmp
    > /var/log/lastlog
}

# Function to reset hostname
reset_hostname() {
    local new_hostname=$1
    log_message "Setting new hostname to: $new_hostname"
    hostnamectl set-hostname "$new_hostname"
    # Update /etc/hosts
    sed -i "s/^127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
}

# Function to set device name
# Sets the device name in various system locations.
#
# This function takes a single argument, the new device name. It updates the
# system-wide device name, PRETTY_NAME in os-release, system identification,
# and systemd machine name.
set_device_name() {
    local device_name=$1
    log_message "Setting device name to: $device_name"
    
    # Update system-wide device name
    echo "$device_name" > /etc/device-name
    
    # Update PRETTY_NAME in os-release
    if [ -f /etc/os-release ]; then
        sed -i "s/PRETTY_NAME=.*/PRETTY_NAME=\"$device_name\"/" /etc/os-release
    fi
    
    # Update system identification
    if [ -f /etc/machine-info ]; then
        echo "PRETTY_HOSTNAME=$device_name" > /etc/machine-info
        echo "DEPLOYMENT=" >> /etc/machine-info
        echo "LOCATION=" >> /etc/machine-info
    else
        echo "PRETTY_HOSTNAME=$device_name" > /etc/machine-info
    fi
    
    # Update systemd machine name
    if command -v hostnamectl &> /dev/null; then
        hostnamectl set-deployment ""
        hostnamectl set-location ""
        hostnamectl set-chassis "vm"
        hostnamectl set-pretty "$device_name"
    fi
}

# Function to backup configurations
# Creates a backup of important system configuration files in /root.
# The backup is stored in a directory with a timestamped name.
backup_configs() {
    local backup_dir="/root/system_config_backup_$(date +%Y%m%d_%H%M%S)"
    log_message "Creating backup in: $backup_dir"
    
    mkdir -p "$backup_dir"
    cp -r /etc/ssh "$backup_dir/" 2>/dev/null || true
    cp /etc/hostname "$backup_dir/" 2>/dev/null || true
    cp /etc/hosts "$backup_dir/" 2>/dev/null || true
    cp /etc/machine-id "$backup_dir/" 2>/dev/null || true
    cp /etc/machine-info "$backup_dir/" 2>/dev/null || true
    cp /etc/os-release "$backup_dir/" 2>/dev/null || true
}

# Main execution
# Main entry point for the script
#
# Confirms with the user whether they are sure they want to reconfigure the
# system. If confirmed, creates a backup of existing configuration files,
# prompts for new hostname and device name if desired, performs the
# reconfigurations, and clears bash history. At the end, informs the user that
# the system should be rebooted to apply all changes.
main() {
    check_root
    
    log_message "Starting system reconfiguration..."
    
    # Confirmation prompt
    read -p "This will reconfigure system information. Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_message "Operation cancelled by user"
        exit 1
    fi
    
    # Create backup
    backup_configs
    
    # Prompt for new hostname and device name
    read -p "Enter new hostname (leave empty to skip): " new_hostname
    read -p "Enter new device name (leave empty to skip): " new_device_name
    
    # Perform reconfigurations
    reset_machine_id
    reset_ssh_keys
    reset_network
    clean_logs
    
    if [ ! -z "$new_hostname" ]; then
        reset_hostname "$new_hostname"
    fi
    
    if [ ! -z "$new_device_name" ]; then
        set_device_name "$new_device_name"
    fi
    
    # Clear bash history
    history -c
    > ~/.bash_history
    
    log_message "System reconfiguration completed successfully"
    log_message "Please reboot the system to apply all changes"
}

# Run main function
main
