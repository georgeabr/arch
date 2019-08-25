#!/bin/bash
# curl https://raw.githubusercontent.com/georgeabr/arch/master/arch-2.sh > arch-2.sh; chmod +x arch-2.sh; cp ./arch-2.sh /mnt; arch-chroot /mnt /bin/bash -c "./arch-2.sh"


printf "\n\nPart 2 - continuing install/customisation.\nConfiguring locale to LONDON/UK.\n"
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc --utc
grep -rl "#en_GB.UTF-8 UTF-8" /etc/locale.gen | xargs sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g'
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8
echo "KEYMAP=uk" > /etc/vconsole.conf
locale-gen

printf "Configuring hostname\n."
echo archie > /etc/hostname
	
printf "Enabling DHCP.\n"
systemctl enable dhcpcd.service

printf "Enabling SSH.\n"
pacman -Sy --noconfirm openssh
systemctl enable sshd.service

printf "Enter ROOT user password:\n"
passwd root
prinf "Adding user _george_, sudo permission\n"
useradd -m -G wheel -s /bin/bash george
grep -rl "# %wheel ALL=(ALL) ALL" /etc/sudoers | xargs sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g'
printf "Enter password for user _george_\n"
passwd george

# %wheel ALL=(ALL) ALL
# grep -rl "# %wheel ALL=(ALL) ALL" /etc/sudoers | xargs sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g'

printf "Installing GRUB.\n"
pacman -Sy --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi  --bootloader-id=grub_uefi --efi-directory=/boot/EFI/ --bootloader-id=GRUB
# single quote ' is '\''
# add nouveau fix, and no mitigations, please
grep -rl " quiet" /etc/default/grub | xargs sed -i 's/ quiet/ quiet mitigations=off '\''acpi_osi=!Windows 2015'\''/g'
grub-mkconfig -o /boot/grub/grub.cfg
mkinitcpio -p linux

printf "Installing Xorg, XFCE, fonts.\n"
pacman -Sy --noconfirm xorg xterm xorg-drivers mc
# printf Section "\""OutputClass"\""\nNew > /etc/X11/xorg.conf.d/20-intel.conf
# printf Section \"OutputClass\" > feck; printf \nIdentifier \"Intel Graphics\" >> feck; cat feck
# add vsync TearFree for intel driver in Xorg
xorg_file="/etc/X11/xorg.conf.d/20-intel.conf"; printf "Section \"OutputClass\"" > $xorg_file; printf "\nIdentifier \"Intel Graphics\"" >> $xorg_file; printf "\nMatchDriver \"i915\"" >> $xorg_file; printf "\nDriver \"intel\"" >> $xorg_file; printf "\nOption \"TearFree\" \"true\"" >> $xorg_file; printf "\nEndSection" >> $xorg_file; nano $xorg_file

pacman -Sy --noconfirm xfce4 sddm mousepad ttf-dejavu ttf-bitstream-vera ttf-liberation noto-fonts
pacman -Sy --noconfirm git networkmanager networkmanager-openvpn nm-connection-editor network-manager-applet wget curl firefox
systemctl enable sddm.service
systemctl enable NetworkManager
timedatectl set-ntp true

printf "\n"
read -p "Work done. Press enter to exit and reboot."
exit
umount -a
reboot
