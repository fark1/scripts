#!/bin/bash

set -e

# ----------------------------
# Function: Ask user to manually partition the disk
# ----------------------------

run_in_chroot() {
    artix-chroot /mnt /bin/bash -c "$1"
}

check_internet() {
    echo "Checking internet connection..."

    if ping -c 3 artixlinux.org >/dev/null 2>&1; then
        echo "Internet is working."
    else
        echo "No internet connection! Please connect before continuing."
        exit 1
    fi
}


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
    basestrap /mnt base base-devel openrc elogind-openrc linux-zen 
    echo "Generating fstab..."
    fstabgen -U /mnt >> /mnt/etc/fstab
}

set_timezone() {
    echo "Setting timezone to Europe/Skopje..."

    run_in_chroot "ln -sf /usr/share/zoneinfo/Europe/Skopje /etc/localtime"
    run_in_chroot "hwclock --systohc"

    echo "Timezone configured."
}

set_locale() {
    echo "Configuring locale..."

    # Enable locale
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen

    # Generate locales
    run_in_chroot "locale-gen"

    # Set system-wide locale
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

    echo "Locale configured system-wide."
}


set_hostname() {
    echo "Setting hostname..."

    # Set hostname
    echo "leviticus" > /mnt/etc/hostname

    # Configure hosts file
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   leviticus.localdomain leviticus
EOF

    echo "Hostname configured as leviticus."
}

set_dns() {
    echo "Configuring DNS..."

    cat > /mnt/etc/resolv.conf <<EOF
nameserver 1.1.1.1   # Cloudflare
nameserver 8.8.8.8   # Google
EOF

    echo "DNS configured."
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