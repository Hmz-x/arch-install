#!/bin/bash

# Program config data
ZONE="America/Indiana/Indianapolis"
LOCALE_1="en_US ISO-8859-1"
LOCALE_2="en_US.UTF-8 UTF-8"

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

set_bootloader()
{
  pacman -Sy
	pacman -S vim grub os-prober efibootmgr
	if [ "$boot_sys" = "BIOS" ]; then
		grub-install --recheck /dev/sda
	else
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
	fi
	grub-mkconfig -o /boot/grub/grub.cfg
}

set_users()
{
	echo "Enter new password for root user."
	passwd

	read -p "Enter new username: " username
	#confirm_in "$username"
	useradd -m "$username"	

	echo "Enter new password for $username."
	passwd "$username"
}

network_config()
{

	read -p "Enter new hostname: " hostname
	confirm_in "$hostname"
	echo "$hostname" > /etc/hostname

	echo "127.0.0.1        localhost" > /etc/hosts
	echo "::1			   localhost" >> /etc/hosts
	echo "127.0.0.1        ${hostname}.localhost ${hostname}" >> /etc/hosts
	
	# extra openrc network configuration step
	[ "$init_sys" = "openrc" ] && echo "hostname='${hostname}'" > /etc/conf.d/hostname

	pacman -S dhclient
}

get_username()
{
	read -p "Enter username: " user
	confirm_in "$user"

	# Add user if user does not exist on system
	id "$user" &> /dev/null || { useradd -m "$user" && passwd "$user"; }
}

set_groups()
{
	groupadd seatd

	usermod root -a -G audio,input,seatd
	usermod "$user" -a -G network,wheel,audio,disk,input,storage,video,seatd
}

set_home()
{
	install -d --owner="$user" --group="$user" --mode=755 \
		"/home/${user}/Documents" "/home/${user}/Documents/pics" "/home/${user}/Videos" \
		"/home/${user}/Music" "/home/${user}/Downloads" "/home/${user}/.local/" \
		"/home/${user}/.local/builds"
}

# Check if script is being run as root
root_check

# Determine boot system
determine_boot

set_time_n_locale
network_config
set_users
set_bootloader
