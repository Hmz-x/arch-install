# Tool For Automating Arch Installation 

This set of scripts is used for automating each part of the arch installation
process. This script can be very easily modified to install distros such
as Artix & etc. as well. Run the scripts in the right order to successfuly
install arch.

## Order of the scripts

```
./format_n_mount.sh
./install_pkgs_n_chroot.sh
./config_base_install.sh
./config_fresh_install.sh
./finish_install.sh
```

## What a complete installation might look like

```
ping www.archlinux.org
# dhclient
pacman-key --init
pacman -Sy
pacman -S git
cd /root
git clone https://github.com/Hmz-x/arch-install
./arch-install/format_n_mount.sh
# If something wrong with fstab entry, fix it and write to /mnt/etc/fstab
# genfstab -U /mnt > /mnt/etc/fstab

./arch-install/install_pkgs_n_chroot.sh
exit # exit out of chroot
umount -R /mnt
reboot

pacman -Sy
pacman -S git
cd /root
git clone https://github.com/Hmz-x/arch-install
./arch-install/config_base_install.sh

./arch-install/config_fresh_install.sh

# Log back in as user
~/.local/bin/arch-install/config_fresh_install.sh
```
