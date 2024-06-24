#!/bin/bash

IFACE="eth0"
DOTFILES_REPO='https://github.com/Hmz-x/dotfiles'

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

establish_netcon()
{
	rfkill unblock 0
	if ping -w 2 www.archlinux.org &> /dev/null; then
		echo "Connected to network."
	else
		echo "Not connected to network."
		echo "Running dhclient..."
		dhclient
	fi	
}

get_username()
{
	read -p "Enter username: " user
	confirm_in "$user" || exit 1

	# Add user if user does not exist on system
	id "$user" &> /dev/null || { useradd "$user" && passwd "$user"; }
}

set_groups()
{
	usermod root -a -G audio,input
	usermod "$user" -a -G network,wheel,audio,disk,input,storage,video
}

set_home()
{
	install -d --owner="$user" --group="$user" --mode=755 "/home/${user}" \
		"/home/${user}/Documents" "/home/${user}/Documents/pics" \
    "/home/${user}/Documents/pics/wallpaper" "/home/${user}/Videos" \
		"/home/${user}/Music" "/home/${user}/Downloads" "/home/${user}/.local/" \
		"/home/${user}/.local/builds"
}

set_dotlocal()
{
	# Set up dotfiles dir
	su "$user" -c "git clone \"$DOTFILES_REPO\" \"/home/${user}/.local/dotfiles\"" &&
    "/home/${user}/.local/dotfiles/dotfiles-install.sh" "$user"

	# Copy arch-install to user /home/${user}/.local/bin/
  if [ -d /root/arch-install ]; then
    cp -vr /root/arch-install "/home/${user}/.local/bin/"

    # Change owner to be $user
    chown -R "${user}:${user}" "/home/${user}/.local/bin/arch-install"
  fi

	# Reboot for changes to sudoers file to take place
	read -p "Press enter key to reboot in order for sudo permissions to apply to user..."
	echo "Log back in as regular user after reboot..."
	sleep 1
	reboot
}

# Check if script is being run as root
root_check

# Establish network connection
establish_netcon

# Get username to work with
get_username

# Set up neccessary groups
set_groups

# Set up dirs in home dir.
set_home

# Pull personal dotfiles from repo and install onto system
set_dotlocal
