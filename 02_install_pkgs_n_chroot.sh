#!/bin/bash

linux_kernel="linux-zen"

# install essential packages
pacstrap -K /mnt base "$linux_kernel" linux-firmware

# Change root into the new system 
arch-chroot /mnt
