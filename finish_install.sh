#!/bin/bash

# Non-graphical packages
NG_PACKAGES_ARR=("rsync" "neovim" "tmux" "docker" "figlet" "make" "python-pip" "npm" \
  "nodejs" "cargo" "ripgrep" "tailscale" "fastfetch" "go" "fakeroot" "debugedit" "cmake" \
  "cxxopts" "timeshift" "tree" "openssh" "pkgconf" "python-pkgconfig" "bash-completion" \
  "starship" "mosh")

# Graphical packages (via pacman)
G_PACKAGES_ARR=("wayland" "qtile" "wlroots" "wlr-protocols" "python-pywlroots" "pipewire" "fnott" \
  "wlsunset" "polkit-kde-agent" "ly" "firefox" "dolphin" "qt6ct" "rofi" "imagemagick" "bluez" \
  "bluez-utils" "pavucontrol" "rofimoji" "alacritty" "brightnessctl" "pamixer" "xorg-xwayland" \
  "signal-desktop" "grim" "speedcrunch" "virtualbox" "virtualbox-host-dkms" "linux-zen-headers" \
  "deluge-gtk" "sxiv" "emoji-font" "nerd-fonts" "otf-font-awesome" "ttf-font-awesome" "noto-fonts" \
  "noto-fonts-emoji" )

# Graphical packages (via yay)
YAY_G_PACKAGES_ARR=("mullvad-vpn-bin" "beeper-latest-bin" "swaylock-effects-git")

confirm_in()
{
	input="$1"
	read -p "${input} - confirm input [Y/n]: " user_ans

	if [ -n "$user_ans" ] && [ "$user_ans" != "y" ] && [ "$user_ans" != "Y" ]; then
		echo "Input is not confirmed. Returning." 2>&1
		return 1
	fi
}

get_username()
{
	read -p "Enter username: " user
	confirm_in "$user" || exit 1

	# Add user if user does not exist on system
	id "$user" &> /dev/null || { useradd "$user" && passwd "$user"; }
}

install_pkgs()
{
  # Update & upgrade system, then install Non-graphical pkgs
  sudo pacman -Syu
  sudo pacman -S "${NG_PACKAGES_ARR[@]}"

  # Upon user confirmation, install graphical pkgs
  read -p "Continue to installation of graphical packages: ${G_PACKAGES_ARR[@]}" ans
	confirm_in "$ans" || return
  sudo pacman -S "${G_PACKAGES_ARR[@]}"
}

install_yay()
{	
  YAY_REPO='https://aur.archlinux.org/yay.git'
	cd "/home/${user}/.local/builds" && git clone "$YAY_REPO" && cd yay && makepkg -si

  # Install yay packages
  yay -Syu
  read -p "Continue to installation of graphical packages: ${YAY_G_PACKAGES_ARR[@]}" ans
	confirm_in "$ans" || return
  yay -S "${YAY_G_PACKAGES_ARR[@]}"
}

install_lunarvim()
{
  LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)
}

configure_env()
{
  echo "Running ssh-keygen..."
  ssh-keygen 

  # download 1 image to ~/Documents/pics/wallpaper just so qtile works properly
  curl https://cutemafia.org/img/metrozu/zu-6926-17.jpeg -o ~/Documents/pics/wallpaper/zu-6926-17.jpeg

	git config --global credential.helper store
  usermod -aG "$user" docker
  sudo ln -s ~/.local/bin/lvim /usr/local/bin/lvim
}

set_services()
{
  systemctl --user enable --now pipewire
  sudo systemctl enable --now docker
  sudo systemctl enable --now ly
  sudo systemctl enable --now bluetooth
}

get_username

install_pkgs

install_yay

install_lunarvim

configure_env

set_services
