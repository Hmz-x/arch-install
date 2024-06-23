#!/bin/bash

<<<<<<< HEAD
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
=======
root_check()
{
	if (($UID!=0)); then
		echo "Run as root. Exitting." 2>&1
		exit 1
	fi
}

determine_largest_disk()
{
  largest_disk=$(lsblk -dno NAME,SIZE | grep -Eo '^[^ ]+' | while read disk; do
      size=$(lsblk -dno SIZE /dev/$disk)
      echo "$size /dev/$disk"
  done | sort -hr | head -n 1 | awk '{print $2}')
>>>>>>> parent of bcf0f35 (replacing fdisk with parted)

  echo "Warning: This script will erase all data on ${largest_disk}. Use with caution."

  read -p "Continue [y/n]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Exiting and avoiding overwrite."; exit 1; }
}

<<<<<<< HEAD
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
=======
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
  # GPT Partition table to be created if boot system is UEFI
  [ "$boot_sys" = "UEFI" ] && partition_table="GPT" && partition_table_symbol="g"
  # MBR(DOS) Partition table to be created if boot system is BIOS
  [ "$boot_sys" = "BIOS" ] && partition_table="MBR/DOS" partition_table_symbol="o"
>>>>>>> parent of bcf0f35 (replacing fdisk with parted)

  echo "Creating new $partition_table partition table on $largest_disk"
  echo -e "${partition_table_symbol}\nw\n" | fdisk "$largest_disk"

  # Create BOOT partition
  echo "Creating Boot partition..."
  echo -e "n\n\n\n\n+512M\nw\n" | fdisk "$largest_disk"

  # Create SWAP partition
  echo "Creating SWAP partition..."
  echo -e "n\n\n\n\n+4G\nw\n" | fdisk "$largest_disk"

  # Create ROOT partition
  echo "Creating ROOT partition..."
  echo -e "n\n\n\n\n+45G\nw\n" | fdisk "$largest_disk"

<<<<<<< HEAD
    echo "Creating HOME partition..."
    parted -s "$largest_disk" mkpart primary ext4 49664MiB 100%
    
    echo "\n\n"
=======
  # Create HOME partition
  echo "Creating HOME partition..."
  echo -e "n\n\n\n\n\ny\nw\n" | fdisk "$largest_disk"

  partprobe "$largest_disk"
>>>>>>> parent of bcf0f35 (replacing fdisk with parted)
}

change_partition_types()
{
<<<<<<< HEAD
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
=======

  # BOOT Partition....................................
  # For UEFI systems, EFI partition type to be assigned
  [ "$boot_sys" = "UEFI" ] && partition_type_num=1
  # For BIOS systems, Linux partition type to be assigned
  [ "$boot_sys" = "BIOS" ] && partition_type_num=83

  # Change BOOT partition type: EFI (UEFI) or Linux (BIOS)
  echo -e "t\n1\n${partition_type_num}w\n" | fdisk "$largest_disk"

  # Set bootable flag on BOOT
  echo -e "a\n1\nw\n" | fdisk "$largest_disk"

  # Change SWAP partition type: SWAP
  echo -e "t\n2\n82w\n" | fdisk "$largest_disk"

  # ROOT Partition....................................
  # For UEFI systems, Linux root (x86-64) partition type to be assigned
  [ "$boot_sys" = "UEFI" ] && partition_type_num=23
  # For BIOS systems, Linux partition type to be assigned
  [ "$boot_sys" = "BIOS" ] && partition_type_num=83

  # Change ROOT partition type: 
  echo -e "t\n3\n${partition_type_num}w\n" | fdisk "$largest_disk"

  # HOME Partition....................................
  # For UEFI systems, Linux home partition type to be assigned
  [ "$boot_sys" = "UEFI" ] && partition_type_num=42
  # For BIOS systems, Linux partition type to be assigned
  [ "$boot_sys" = "BIOS" ] && partition_type_num=83

  # Change HOME partition type
  echo -e "t\n4\n${partition_type_num}w\n" | fdisk "$largest_disk"

  partprobe "$largest_disk"
}

verify_partition_table()
{
  echo "Displaying created structure of ${largest_disk}:"
  fdisk -l "$largest_disk"
>>>>>>> parent of bcf0f35 (replacing fdisk with parted)
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

# Mount partitions
mount_partitions

# Verify partition table
verify_partition_table
