#!/bin/bash

# Default wallpaper image source
DEF_IMG_SRC="https://archive.org/download/metro-zu-art-1/1029179.jpg"

# Non-graphical packages
NG_PACKAGES_ARR=("vim" "rsync" "neovim" "tmux" "docker" "figlet" "make" "python-pip" "npm" \
  "nodejs" "cargo" "ripgrep" "tailscale" "fastfetch" "go" "fakeroot" "debugedit" "cmake" \
  "cxxopts" "timeshift" "tree" "openssh" "pkgconf" "python-pkgconfig" "bash-completion" \
  "starship" "mosh" "pass" "pipewire-pulse" "python-psutil" "man-pages" "man-db" \
  "unzip" "rar" "kubectl" "kube-proxy" "kubelet" "minikube" "docker-compose" \
  "openntpd" "cronie" "ufw" "wget" "networkmanager" "wireshark-qt" "wl-clipboard" "wtype" \
  "wofi" "xorg-server" "xorg-xinit" "xsel" "xclip" "xorg-xclipboard" "rtkit" "shellcheck" \
  "alsa-firmware" "alsa-tools" "alsa-utils" "autoconf" "automake" "libdaq" "libdnet" \
  "flex" "hwloc" "tor" "nmap" "proxychains-ng" "android-sdk-platform-tools" \
  "android-udev" "bc" "yq" "entr")

# Graphical packages (via pacman)
G_PACKAGES_ARR=("wayland" "qtile" "wlroots" "wlr-protocols" "python-pywlroots" "pipewire" "fnott" \
  "wlsunset" "polkit-kde-agent" "ly" "firefox" "dolphin" "qt6ct" "rofi" "imagemagick" "bluez" \
  "bluez-utils" "pavucontrol" "rofimoji" "alacritty" "brightnessctl" "pamixer" "xorg-xwayland" \
  "signal-desktop" "grim" "speedcrunch" "virtualbox" "virtualbox-host-dkms" "linux-zen-headers" \
  "deluge-gtk" "sxiv" "emoji-font" "nerd-fonts" "otf-font-awesome" "ttf-font-awesome" "noto-fonts" \
  "noto-fonts-emoji" "python-dbus-next" "notification-daemon" "mpv" \
  "sof-firmware" "vulkan-radeon" "bluez" "blueman")

# Graphical packages (via yay)
YAY_G_PACKAGES_ARR=("mullvad-vpn-bin" "beeper-latest-bin" "swaylock-effects-git" \
  "notify-send-py" "slack-desktop-wayland") 

confirm_in()
{
	input="$1"
	read -rp "${input} - confirm input [Y/n]: " user_ans

	if [ -n "$user_ans" ] && [ "$user_ans" != "y" ] && [ "$user_ans" != "Y" ]; then
		echo "Input is not confirmed. Returning." 2>&1
		return 1
	fi
}

get_username()
{
	read -rp "Enter username: " user
	confirm_in "$user" || exit 1

	# Add user if user does not exist on system
	id "$user" &> /dev/null || { useradd "$user" && passwd "$user"; }
}

install_loop()
{
    pkgs_arr=("$@")
    for pkg in "${pkgs_arr[@]}"; do
        sudo pacman --needed --noconfirm -S "$pkg"
    done
}

install_pkgs()
{
  # Update & upgrade system, then install Non-graphical pkgs
  sudo pacman --noconfirm -Syu
  echo "Installing: ${NG_PACKAGES_ARR[*]}.."
  install_loop "${NG_PACKAGES_ARR[@]}"

  # Upon user confirmation, install graphical pkgs
  confirm_in "Continue to installation of graphical packages via pacman: \
${G_PACKAGES_ARR[*]}" || return
  install_loop "${G_PACKAGES_ARR[@]}"
}

install_yay()
{	
  YAY_REPO='https://aur.archlinux.org/yay.git'
	cd "/home/${user}/.local/builds" && git clone "$YAY_REPO" && cd yay && makepkg -si

  # Install yay packages
  yay --noconfirm -Syu
  confirm_in "Continue to installation of graphical packages via yay: \
${YAY_G_PACKAGES_ARR[*]}" || return
  yay --needed --noconfirm -S "${YAY_G_PACKAGES_ARR[@]}"
}

install_lunarvim()
{

  confirm_in "Continue to installation of lvim" || return
  LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)
}

set_vim_plugins()
{
	git clone https://github.com/VundleVim/Vundle.vim.git \
		"/home/${user}/.vim/bundle/Vundle.vim"
	vim +PluginInstall +qall
}

set_tmux_plugin_manager()
{
  git clone https://github.com/tmux-plugins/tpm "/home/${user}/tmux/plugins/tpm"
}

configure_env()
{
  # ssh
  echo "Running ssh-keygen..."
  ssh-keygen 

  # download the default wallpaper image to ~/Documents/pics/wallpaper just so qtile works properly
  curl "$DEF_IMG_SRC" -Lo ~/Documents/pics/wallpaper/default.jpeg

  # git
	git config --global credential.helper store

  # docker
  usermod "$user" -aG docker

  # lvim
  sudo ln -s ~/.local/bin/lvim /usr/local/bin/lvim

  # set proper perms for dumpcap
  sudo chmod 755 /sbin/dumpcap

  # adb + fastboot
  sudo ln -sf /opt/android-sdk-platform-tools/adb /usr/local/bin/adb
  sudo ln -sf /opt/android-sdk-platform-tools/fastboot /usr/local/bin/fastboot

  # set up proxychains config
  git clone https://github.com/Hmz-x/botnet-control ~/.local/src/botnet-control
  sudo cp ~/.local/src/botnet-control/proxychains.conf /etc/proxychains.conf

  # set up saphyra
  git clone https://github.com/niedong/saphyra ~/.local/bin/saphyra
  chmod 755 ~/.local/bin/saphyra/saphyra.py
  sudo ln -sf ~/.local/bin/saphyra/saphyra.py /usr/local/bin/saphyra.py
}

set_services()
{
  systemctl --user enable --now pipewire
  systemctl --user enable --now pipewire-pulse
  sudo systemctl enable --now NetworkManager
  sudo systemctl enable --now docker
  sudo systemctl enable --now ly
  sudo systemctl enable --now bluetooth
  sudo systemctl enable --now openntpd
  sudo systemctl enable --now cronie
}

get_username

install_pkgs

install_yay

install_lunarvim

set_vim_plugins

set_tmux_plugin_manager

configure_env

set_services
