#!/bin/bash

confirm_in()
{
    input="$1"
    read -rp "${input} - confirm input [Y/n]: " user_ans

    if [ -n "$user_ans" ] && [ "$user_ans" != "y" ] && [ "$user_ans" != "Y" ]; then
        echo "Input is not confirmed. Returning." 2>&1
        return 1
    fi
}

root_check() 
{
    if [[ $UID -ne 0 ]]; then
        echo "Run as root. Exiting." >&2
        exit 1
    fi
}

determine_largest_disk() 
{
    largest_disk=$(lsblk -dno NAME,SIZE | 
      while read -r disk size; do 
        echo "$size /dev/$disk"
      done | sort -hr | head -n 1 | awk '{print $2}')

    echo "Warning: This script will erase all data on ${largest_disk}. Use with caution."

    read -rp "Continue [y/n]: " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Exiting and avoiding overwrite."; exit 1; }
}

determine_boot() 
{
    if [ -d /sys/firmware/efi ]; then
        boot_sys="UEFI"
    else
        boot_sys="BIOS"
    fi
}

create_partition_table() 
{
    if [ "$boot_sys" = "UEFI" ]; then
        partition_table="gpt"
    else
        partition_table="msdos"
    fi

    echo "Wiping $largest_disk..."
    wipefs -a "$largest_disk"
    dd if=/dev/zero of="$largest_disk" bs=1M count=10 status=progress

    echo "Creating new $partition_table partition table on $largest_disk"
    parted -s "$largest_disk" mklabel "$partition_table"

    # Display the size of the largest disk
    disk_size=$(lsblk -dno SIZE "$largest_disk")
    echo "Disk Size of $largest_disk: $disk_size"

    # Create partitions
    echo "Creating Boot partition (1024 MiB)..."
    parted -s "$largest_disk" mkpart primary fat32 1MiB 1025MiB
    [ "$boot_sys" = "UEFI" ] && parted -s "$largest_disk" set 1 boot on

    echo "Creating ROOT partition (50 GiB)..."
    parted -s "$largest_disk" mkpart primary ext4 1025MiB 51225MiB

    echo "Creating SWAP partition (16 GiB)..."
    home_start_mib=$((51225 + 16384))  # Reserve 16 GiB for SWAP
    parted -s "$largest_disk" mkpart primary linux-swap 51225MiB "$home_start_mib"MiB

    # Calculate remaining free space
    total_disk_size_mib=$(lsblk -dno SIZE "$largest_disk" | awk '{print int($1 * 1024)}')  # Convert GiB to MiB
    free_space_mib=$((total_disk_size_mib - home_start_mib))
    free_space_gib=$((free_space_mib / 1024))

    echo "Remaining free space: ${free_space_gib} GiB"

    # Ask user for HOME partition size
    read -rp "Enter size for HOME partition in GiB (max: ${free_space_gib} GiB): " home_size_gb
    if ! [[ "$home_size_gb" =~ ^[0-9]+$ ]] || [ "$home_size_gb" -gt "$free_space_gib" ]; then
        echo "Invalid input. Defaulting HOME partition size to ${free_space_gib} GiB."
        home_size_gb=$free_space_gib
    fi

    home_size_mib=$((home_size_gb * 1024))
    home_end_mib=$((home_start_mib + home_size_mib))

    echo "Creating HOME partition (${home_size_gb} GiB)..."
    parted -s "$largest_disk" mkpart primary ext4 "${home_start_mib}MiB" "${home_end_mib}MiB"

    echo "Partitioning completed successfully."
    echo -e "\n\n"
}

change_partition_types()
{
    if [ "$boot_sys" = "BIOS" ]; then
        echo "Setting first partition as bootable..."
        parted -s "$largest_disk" set 1 boot on
    fi
}

create_fs()
{
    [ "$largest_disk" == "/dev/sda" ] && disk_partition="$largest_disk"
    [ "$largest_disk" == "/dev/nvme0n1" ] && disk_partition="${largest_disk}p"

    echo "Formatting BOOT partition..."
    if [ "$boot_sys" = "UEFI" ]; then
        mkfs.fat -F32 "${disk_partition}1"
    else
        mkfs.ext4 "${disk_partition}1"
    fi

    echo "Formatting ROOT partition as ext4..."
    mkfs.ext4 "${disk_partition}3"

    echo "Formatting SWAP partition..."
    mkswap "${disk_partition}2"

    echo "Formatting HOME partition as ext4..."
    mkfs.ext4 "${disk_partition}4"

    echo -e "\n\n"
}

mount_partitions()
{
    echo "Mounting ROOT partition to /mnt..."
    mount "${disk_partition}3" /mnt/

    echo "Mounting BOOT partition to /mnt/boot..."
    [ ! -d /mnt/boot ] && mkdir /mnt/boot
    mount "${disk_partition}1" /mnt/boot

    echo "Activating SWAP partition..."
    swapon "${disk_partition}2"

    echo "Mounting HOME partition to /mnt/home..."
    mount --mkdir "${disk_partition}4" /mnt/home

    echo -e "\n\n"
}

verify_partition_table() 
{
    echo "Displaying created structure of ${largest_disk}:"
    parted "$largest_disk" print
    echo -e "\n\n"

    echo "Displaying results for 'genfstab -U /mnt'"
    genfstab -U /mnt

    echo -e "\n\n"
}

# Check if script is being run as root
root_check

# Determine disk to work on and get user confirmation for the script to continue 
determine_largest_disk

# Determine boot system
determine_boot

# Create new partition table and partitions
create_partition_table

# Change partition types
change_partition_types

# Create File System for each partition
create_fs

# Mount partitions
mount_partitions

# Verify partition table
verify_partition_table
