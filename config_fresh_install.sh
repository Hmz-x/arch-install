#!/bin/bash

IFACE="eth0"
DOTFILES_REPO='https://github.com/Hmz-x/dotfiles'

root_check() 
{
    if [[ $UID -ne 0 ]]; then
        echo "Run as root. Exiting." >&2
        exit 1
    fi
}

set_ethernet()
{
	rfkill unblock 0
	if ip a | grep -q "inet .*${IFACE}" && ip link show "$IFACE" | grep -q "state UP"; then
		echo "Ethernet connected."
	else
		echo "Ethernet not connected."
		echo "Running dhclient..."
		dhclient "$IFACE"	
	fi	
}

get_username()
{
	read -p "Enter username: " user
	confirm_in "$user" || exit 1

	# Add user if user does not exist on system
	id "$user" &> /dev/null || { useradd -m "$user" && passwd "$user"; }
}

set_groups()
{
	usermod root -a -G audio,input
	usermod "$user" -a -G network,wheel,audio,disk,input,storage,video
}

set_home()
{
	install -d --owner="$user" --group="$user" --mode=755 \
		"/home/${user}/Documents" "/home/${user}/Documents/pics" "/home/${user}/Videos" \
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
    cp -vr /root/arch-install "/home/${user}/.local/bin"

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

# Establish ethernet connection
#set_ethernet

# Get username to work with
get_username

# Set up neccessary groups
set_groups

# Set up dirs in home dir.
set_home

# Pull personal dotfiles from repo and install onto system
set_dotlocal
