#!/bin/bash

packages_arr=("wayland" "pipewire" "qtile" "fnott" "wlsunset" "polkit-kde-authentication-agent" \
  "neovim" "tmux" "ly" "firefox" "librewolf-bin" "docker")

install_pkgs()
{
  sudo pacman -Syu
  sudo pacman -S "${packages_arr[@]}"
}

install_lunarvim()
{

 : 
}

set_services()
{
  # Set up pipewire service
  # Set up docker service
  # Set up ly service
  #
}

install_pkgs

install_lunarvim

set_services
