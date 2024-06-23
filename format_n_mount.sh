#!/bin/bash

root_check() 
{
    if [[ $UID -ne 0 ]]; then
        echo "Run as root. Exiting." >&2
        exit 1
    fi
}

determine_largest_disk() 
{
    largest_disk=$(lsblk -dno NAME,SIZE | grep -Eo '^[^ ]+' | while read disk; do
        size=$(lsblk -dno SIZE /dev/$disk)
        echo "$size /dev/$disk"
    done | sort -hr | head -n 1 | awk '{print $2}')

    echo "Warning: This script will erase all data on ${largest_disk}. Use with caution."

    read -p "Continue [y/n]: " ans
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

    echo "Creating new $partition_table partition table on $largest_disk"
    parted -s "$largest_disk" mklabel "$partition_table"

    # Create partitions
    echo "Creating Boot partition..."
    parted -s "$largest_disk" mkpart primary fat32 1MiB 513MiB
    [ "$boot_sys" = "UEFI" ] && parted -s "$largest_disk" set 1 boot on

    echo "Creating SWAP partition..."
    parted -s "$largest_disk" mkpart primary linux-swap 513MiB 4617MiB

    echo "Creating ROOT partition..."
    parted -s "$largest_disk" mkpart primary ext4 4617MiB 49664MiB

    echo "Creating HOME partition..."
    parted -s "$largest_disk" mkpart primary ext4 49664MiB 100%
    
    echo "\n\n"
}

change_partition_types()
{
    # For UEFI systems, EFI partition type is set during creation
    # For BIOS systems, the boot flag needs to be set and the type needs to be linux
    if [ "$boot_sys" = "BIOS" ]; then
        parted -s "$largest_disk" set 1 boot on
    fi

    echo "Setting partition names..."
    parted -s "$largest_disk" name 1 'BOOT'
    parted -s "$largest_disk" name 3 'ROOT'
    parted -s "$largest_disk" name 4 'HOME'

    echo "\n\n"
}

create_fs()
{
    # /dev/sda partition format: /dev/sdaX
    [ "$largest_disk" == "/dev/sda" ] && disk_partition="$largest_disk"
    # /dev/nvme0n1 partition format: /dev/nvme0n1pX
    [ "$largest_disk" == "/dev/nvme0n1" ] && disk_partition="${largest_disk}p"

    if [ "$boot_sys" = "UEFI" ]; then
      echo "Formatting BOOT partition as FAT32..."
      mkfs.fat -F32 "${disk_partition}1"
    else
      echo "Formatting BOOT partition as ext4..."
      mkfs.ext4 "${disk_partition}1"
    fi

    echo "Formatting SWAP partition..."
    mkswap "${disk_partition}2" 

    echo "Formatting ROOT partition as ext4..."
    mkfs.ext4 "${disk_partition}3"

    echo "Formatting HOME partition as ext4..."
    mkfs.ext4 "${disk_partition}4"

    echo "\n\n"
}

mount_partitions()
{
    echo "Mounting BOOT partition to /mnt/boot..."
    mount --mkdir -L BOOT /mnt/boot

    echo "Activating SWAP partition..."
    swapon "${disk_partition}2"

    echo "Mounting ROOT partition to /mnt..."
    mount -L ROOT /mnt

    echo "Mounting HOME partition to /mnt/home..."
    mount --mkdir -L HOME /mnt/home

    echo "\n\n"
}


verify_partition_table() 
{
    echo "Displaying created structure of ${largest_disk}:"
    parted "$largest_disk" print
}

# Check if script is being run as root
root_check

# Determine disk to work on and get user confirmation for the script to continue 
determine_largest_disk

# Determine boot system
determine_boot

# Create new GPT partition table and partitions
create_partition_table

# Change partition types
change_partition_types

# Create File System for each partition
create_fs

# Verify partition table
verify_partition_table
