#!/bin/bash

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
  # GPT Partition table to be created if boot system is UEFI
  [ "$boot_sys" = "UEFI" ] && partition_table="GPT" && partition_table_symbol="g"
  # MBR(DOS) Partition table to be created if boot system is BIOS
  [ "$boot_sys" = "BIOS" ] && partition_table="MBR/DOS" partition_table_symbol="o"

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

  # Create HOME partition
  echo "Creating HOME partition..."
  echo -e "n\n\n\n\n\nw\n" | fdisk "$largest_disk"
}

change_partition_types()
{

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
}

verify_partition_table()
{
  echo "Displaying created structure of ${largest_disk}:"
  fdisk -l "$largest_disk"
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

# Verify partition table
verify_partition_table
