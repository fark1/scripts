#!/bin/bash

set -e

# ----------------------------
# Function: Ask user to manually partition the disk
# ----------------------------
manual_partition() {
    echo "Please manually partition your disk using cfdisk, parted, or gdisk."
    echo "After finishing, press 'y' to continue or 'n' to abort."
    read -r answer
    if [[ "$answer" != "y" ]]; then
        echo "Aborting installation."
        exit 1
    fi

    # Ask for the partitions
    read -rp "Enter EFI partition (e.g., /dev/sda1): " EFI_PART
    read -rp "Enter root partition (e.g., /dev/sda2): " ROOT_PART
    read -rp "Enter swap partition (e.g., /dev/sda3): " SWAP_PART
}

# ----------------------------
# Function: Format the partitions
# ----------------------------
format_partitions() {
    echo "Formatting EFI partition as FAT32..."
    mkfs.fat -F32 "$EFI_PART"

    echo "Formatting root partition as ext4..."
    mkfs.ext4 "$ROOT_PART"

    echo "Setting up swap partition..."
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
}

# ----------------------------
# Function: Mount the partitions
# ----------------------------
mount_partitions() {
    echo "Mounting root partition to /mnt..."
    mount "$ROOT_PART" /mnt

    echo "Creating /mnt/boot and mounting EFI partition..."
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
}

# ----------------------------
# Function: Synchronize system clock (OpenRC live)
# ----------------------------
sync_clock() {
    echo "Starting NTP to sync system clock..."
    rc-service ntpd start
}

# ----------------------------
# Function: Bootstrap base Artix system
# ----------------------------
bootstrap_base() {
    echo "Bootstrapping base system..."
    basestrap /mnt base base-devel openrc elogind-openrc
    echo "Generating fstab..."
    fstabgen -U /mnt >> /mnt/etc/fstab
}

# ----------------------------
# Main script execution
# ----------------------------
echo "Starting Artix installation..."

manual_partition
format_partitions
mount_partitions
sync_clock
bootstrap_base

echo "Base installation complete!"