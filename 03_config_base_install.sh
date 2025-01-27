#!/bin/bash

# Program config data
#ZONE="America/Indiana/Indianapolis"
ZONE="Turkey"
LOCALE_1="en_US ISO-8859-1"
LOCALE_2="en_US.UTF-8 UTF-8"

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

determine_boot()
{
	if [ -d /sys/firmware/efi ]; then
		boot_sys="UEFI"
	else
		boot_sys="BIOS"
	fi
}

set_time_n_locale()
{
	ln -sf /usr/share/zoneinfo/"${ZONE}" /etc/localtime
	hwclock --systohc

	echo "$LOCALE_1" > /etc/locale.gen
	echo "$LOCALE_2" >> /etc/locale.gen
	locale-gen
	
	locale_str="$(echo "$LOCALE_2" | cut -d ' ' -f 1)"
	echo "export LANG=\"${locale_str}\"" > /etc/locale.conf
	echo "export LC_COLLATE=\"C\"" >> /etc/locale.conf
}


set_users()
{
	echo "Enter new password for root user."
	passwd

	read -rp "Enter new username: " username
	confirm_in "$username" || return 1
	useradd "$username"	

	echo "Enter new password for $username."
	passwd "$username"
}

network_config()
{

	read -rp "Enter new hostname: " hostname
	confirm_in "$hostname" || return 1
	echo "$hostname" > /etc/hostname

	echo "127.0.0.1        localhost" > /etc/hosts
	echo "::1			   localhost" >> /etc/hosts
	echo "127.0.0.1        ${hostname}.localhost ${hostname}" >> /etc/hosts
	
	# extra openrc network configuration step if init_sys was implemented:
	#[ "$init_sys" = "openrc" ] && echo "hostname='${hostname}'" > /etc/conf.d/hostname

	pacman -S dhclient
}

set_bootloader()
{
  pacman -Sy
	pacman -S sudo vim grub os-prober efibootmgr
	if [ "$boot_sys" = "BIOS" ]; then
    largest_disk=$(lsblk -dno NAME,SIZE | 
      while read -r disk size; do 
        echo "$size /dev/$disk"
      done | sort -hr | head -n 1 | awk '{print $2}')

    grub-install --recheck "$largest_disk"
	else
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
	fi
	grub-mkconfig -o /boot/grub/grub.cfg

  if ! mount | grep -q '/mnt/boot/efi'; then
    echo "Error: Nothing is mounted to /boot/efi."
  else
    echo "Successfully mounted boot partition to /boot/efi."
  fi
}

# Check if script is being run as root
root_check

# Determine boot system
determine_boot

# Set up time and locale
set_time_n_locale

# Set up network
network_config

# Set up users
set_users

# Set bootloader: install grub and run grub-install
set_bootloader
