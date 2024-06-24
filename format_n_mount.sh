#!/bin/bash

confirm_in()
{
	input="$1"
	read -p "${input} - confirm input [Y/n]: " user_ans

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

    echo -e "\n\n"
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

    echo -e "\n\n"
}

change_partition_types()
{
    if [ "$boot_sys" = "BIOS" ]; then
        echo "Setting first partition as bootable..."
        parted -s "$largest_disk" set 1 boot on
    fi

#   Setting partition names does not work on my BIOS system as of current..
#   Error: loop disk labels do not support partition name.
#    echo "Setting partition names..."
#    parted -s "$largest_disk" name 1 'BOOT'
#    parted -s "$largest_disk" name 2 'SWAP'
#    parted -s "$largest_disk" name 3 'ROOT'
#    parted -s "$largest_disk" name 4 'HOME'

    echo -e "\n\n"
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

    echo -e "\n\n"
}

mount_partitions()
{
    echo "Mounting BOOT partition to /mnt/boot..."
    [ ! -d /mnt/boot ] && mkdir /mnt/boot
    mount /dev/sda1 /mnt/boot

    echo "Activating SWAP partition..."
    swapon "${disk_partition}2"

    echo "Mounting ROOT partition to /mnt..."
    mount /dev/sda3 /mnt/

    echo "Mounting HOME partition to /mnt/home..."
    mount --mkdir /dev/sda4 /mnt/home

    echo -e "\n\n"
}

verify_partition_table() 
{
    echo "Displaying created structure of ${largest_disk}:"
    parted "$largest_disk" print
    echo -e "\n\n"

    echo "Check for correct mount points:"
    lsblk "$largest_disk"
    echo -e "\n\n"

    echo "Displaying results for 'genfstab -U /mnt'"
    echo "If boot partition does not show simply (re)mount ${disk_partition}1 to /mnt/boot"
    genfstab -U /mnt
    [ ! -d /mnt/etc ] && mkdir /mnt/etc
    echo -e "\n\n"

    #read -p "Write current partition table to /mnt/etc/fstab [y/n]: "
    #[[ "$ans" == "y" || "$ans" == "Y" ]] && genfstab -U /mnt > /mnt/etc/fstab

    read -p "Mount ${disk_partition}1 to /mnt/boot" ans
    confirm_in "$ans" || return

    [ ! -d /mnt/boot ] && mkdir /mnt/boot
    mount "${disk_partition}1" /mnt/boot
}

add_boot_to_fstab() {

    # Return if user selects answers besides y or Y
    read -p "Add boot partition to /mnt/etc/fstab [y/n]: " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || return 0

    # Ensure that the boot partition is mounted
    if ! mount | grep -q "/mnt/boot"; then
        echo "Boot partition is not mounted. Please mount it first."
        return 1
    fi

    # Get the UUID of the boot partition
    boot_uuid=$(blkid -s UUID -o value "${disk_partition}1")
    
    # Ensure the UUID was found
    if [ -z "$boot_uuid" ]; then
        echo "Could not find UUID for boot partition."
        return 1
    fi

    # Check if the UUID is already in fstab
    if grep -q "$boot_uuid" /mnt/etc/fstab; then
        echo "Entry for the boot partition already exists in /mnt/etc/fstab."
        return 0
    fi

    # Add the boot partition entry to /mnt/etc/fstab
    echo "# ${disk_partition}1" >> /mnt/etc/fstab
    echo "UUID=$boot_uuid  /boot  vfat  rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro  0 2" >> /mnt/etc/fstab
    echo "Boot partition added to /mnt/etc/fstab:"
    tail -n 2 /mnt/etc/fstab
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

# Add boot partition to fstab (If user chooses so)
#add_boot_to_fstab
