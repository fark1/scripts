#!/bin/bash
set -e

# ----------------------------
# Function: Run command inside chroot
# ----------------------------
run_in_chroot() {
    artix-chroot /mnt /bin/bash -c "$1"
}

# ----------------------------
# Function: Check internet connection
# ----------------------------
check_internet() {
    echo "Checking internet connection..."
    if ping -c 3 artixlinux.org >/dev/null 2>&1; then
        echo "Internet is working."
    else
        echo "No internet connection! Please connect before continuing."
        exit 1
    fi
}

# ----------------------------
# Function: Manual partition prompt
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

    # Add swap to fstab for persistence
    echo "$SWAP_PART none swap sw 0 0" >> /mnt/etc/fstab
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
# Function: Copy mirrorlist
# ----------------------------
copy_mirrorlist() {
    local source_file="$PWD/mirrorlist"   # your mirrorlist in scripts folder
    local target_file="/mnt/etc/pacman.d/mirrorlist"

    if [[ ! -f "$source_file" ]]; then
        echo "Mirrorlist file not found: $source_file"
        exit 1
    fi

    mkdir -p "$(dirname "$target_file")"
    cp "$source_file" "$target_file"
    echo "Mirrorlist copied to $target_file"
}

# ----------------------------
# Function: Synchronize system clock
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

# ----------------------------
# Function: Set timezone
# ----------------------------
set_timezone() {
    echo "Setting timezone to Europe/Skopje..."
    run_in_chroot "ln -sf /usr/share/zoneinfo/Europe/Skopje /etc/localtime"
    run_in_chroot "hwclock --systohc"
    echo "Timezone configured."
}

# ----------------------------
# Function: Set locale
# ----------------------------
set_locale() {
    echo "Configuring locale..."
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
    run_in_chroot "locale-gen"
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    echo "Locale configured system-wide."
}

# ----------------------------
# Function: Set hostname
# ----------------------------
set_hostname() {
    echo "Setting hostname..."
    echo "leviticus" > /mnt/etc/hostname
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   leviticus.localdomain leviticus
EOF
    echo "Hostname configured."
}

# ----------------------------
# Function: Set DNS
# ----------------------------
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

check_internet
manual_partition
format_partitions
mount_partitions
copy_mirrorlist
sync_clock
bootstrap_base
set_timezone
set_locale
set_hostname
set_dns