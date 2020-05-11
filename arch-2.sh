#!/bin/bash
# curl https://raw.githubusercontent.com/georgeabr/arch/master/arch-2.sh > arch-2.sh; chmod +x arch-2.sh; cp ./arch-2.sh /mnt; arch-chroot /mnt /bin/bash -c "./arch-2.sh"


printf "\n\nPart 2 - continuing install/customisation.\nConfiguring locale to LONDON/UK.\n"
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc --utc
grep -rl "#en_GB.UTF-8 UTF-8" /etc/locale.gen | xargs sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g'
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8
# localectl list-keymaps - use to list available keymaps
echo "KEYMAP=uk" > /etc/vconsole.conf
locale-gen

printf "Configuring hostname\n."
echo archie > /etc/hostname
	
# printf "Enabling DHCP.\n"
# systemctl enable dhcpcd.service

printf "Enabling SSH.\n"
pacman -Sy --noconfirm openssh
systemctl enable sshd.service

# %wheel ALL=(ALL) ALL
# grep -rl "# %wheel ALL=(ALL) ALL" /etc/sudoers | xargs sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g'

printf "\nRanking and adding mirrors\n"
pacman -Sy --noconfirm pacman-contrib
curl -s "https://www.archlinux.org/mirrorlist/?&country=GB&protocol=http&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist 

printf "Installing GRUB.\n"
pacman -Sy --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi  --bootloader-id=grub_uefi --efi-directory=/boot/EFI/ --bootloader-id="Arch Linux"
# single quote ' is '\''
# add nouveau fix, and no mitigations, please
grep -rl " quiet" /etc/default/grub | xargs sed -i 's/ quiet/ quiet mitigations=off selinux=0 '\''acpi_osi=!Windows 2015'\''/g'
grub-mkconfig -o /boot/grub/grub.cfg
mkinitcpio -p linux

printf "Enabling multilib.\n"
pacman_file="/etc/pacman.conf"; printf "\n\n# Enabling multilib." >> $pacman_file; printf "\n[multilib]" >> $pacman_file; printf "\nInclude = /etc/pacman.d/mirrorlist\n" >> $pacman_file

# add in ~/.gtkrc-2.0
# gtk-cursor-blink = 0

# /etc/pacman.conf

printf "Installing Xorg, XFCE, fonts, Intel microcode, NTFS.\n"
pacman -Sy --noconfirm intel-ucode ntfs-3g pulseaudio pulseaudio-alsa pavucontrol hsetroot
pacman -Sy --noconfirm xorg xterm xorg-drivers mc nano gvfs xarchiver udiskie udisks2
# printf Section "\""OutputClass"\""\nNew > /etc/X11/xorg.conf.d/20-intel.conf
# printf Section \"OutputClass\" > xyz; printf \nIdentifier \"Intel Graphics\" >> xyz; cat xyz
# add vsync TearFree for intel driver in Xorg

xorg_file="/etc/X11/xorg.conf.d/20-intel.conf"; printf "Section \"Device\"" > $xorg_file; printf "\nIdentifier \"Intel Graphics\"" >> $xorg_file; printf "\nDriver \"intel\"" >> $xorg_file; printf "\nOption \"TearFree\" \"true\"" >> $xorg_file; printf "\nEndSection" >> $xorg_file;

# swap=yes, etc, ntp=NO, grub=yes
# xorg_file="/etc/X11/xorg.conf.d/20-intel.conf"; printf "Section \"OutputClass\"" > $xorg_file; printf "\nIdentifier \"Intel Graphics\"" >> $xorg_file; printf "\nMatchDriver \"i915\"" >> $xorg_file; printf "\nDriver \"intel\"" >> $xorg_file; printf "\nOption \"TearFree\" \"true\"" >> $xorg_file; printf "\nEndSection" >> $xorg_file;

pacman -Sy --noconfirm xfce4 xfce4-goodies xfce-polkit sddm mousepad ttf-dejavu ttf-roboto-mono ttf-bitstream-vera ttf-liberation noto-fonts redshift gnupg
pacman -Sy --noconfirm git networkmanager networkmanager-openvpn nm-connection-editor network-manager-applet wget firefox unzip unrar
systemctl enable sddm.service
systemctl enable NetworkManager
systemctl start NetworkManager

# do user creation after everything is installed
printf "\nEnter ROOT user password:\n"
passwd root
printf "\nAdding user _george_, sudo permission\n"
useradd -m -G wheel -s /bin/bash george
grep -rl "# %wheel ALL=(ALL) ALL" /etc/sudoers | xargs sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g'
printf "Enter password for user _george_\n"
passwd george


# does not work from chroot
# timedatectl set-ntp true

# to be done by user, copy file to root, execute as regular user

mkhomedir_helper george
# printf "\041" - meaning !
#!/bin/bash

# ~/.config/gtk-3.0/settings.ini
mkdir /home/george/.config; chown george:george /home/george/.config
mkdir /home/george/.config/gtk-3.0; chown george:george /home/george/.config/gtk-3.0
printf "[Settings]" > /home/george/.config/gtk-3.0/settings.ini
printf "\ngtk-cursor-blink = 0" >> /home/george/.config/gtk-3.0/settings.ini
# consistency for all GTK3 apps, including Firefox
printf "gtk-cursor-theme-name = Adwaita" >> /home/george/.config/gtk-3.0/settings.ini
printf "gtk-cursor-theme-size = 32" >> /home/george/.config/gtk-3.0/settings.ini
chown george:george /home/george/.config/gtk-3.0/settings.ini

# for gtk2, including under kde
printf "\ngtk-cursor-blink = 0" >> /home/george/.gtkrc-2.0
printf "\ngtk-cursor-blink = 0" >> /home/george/.gtkrc-2.0-kde
chown george:george /home/george/.gtkrc-2.0
chown george:george /home/george/.gtkrc-2.0-kde

# install trizen on first user console login
home_script="/home/george/welcome.sh"; printf "#\041/bin/bash\n" > $home_script; printf "\ntimedatectl set-ntp true" >> $home_script
printf "\nlocalectl set-x11-keymap gb pc105" >> $home_script
printf "\ngpg --recv-keys C1A60EACE707FDA5" >> $home_script
printf "\ngit clone https://aur.archlinux.org/trizen.git" >> $home_script
printf "\ncd trizen" >> $home_script
printf "\nmakepkg -si" >> $home_script

# install some AUR packages
printf "\ntrizen -S --noedit freetype2-infinality-remix fontconfig-infinality-remix cairo-infinality-remix" >> $home_script
# printf "\ngpg --recv-keys C1A60EACE707FDA5" >> $home_script
# printf "\ntrizen -S --noedit freetype2-cleartype" >> $home_script


# timedatectl set-ntp true
# localectl set-x11-keymap gb pc105
# git clone https://aur.archlinux.org/trizen.git
# cd trizen
# makepkg -si

chown george:george /home/george/welcome.sh
chmod +x /home/george/welcome.sh
printf "./welcome.sh; sed -i '/welcome/d' ~/.bashrc" >> /home/george/.bashrc
printf "\n" >> /home/george/.bashrc
# delete line after executing it; good for first-time config
# printf "Hello from bash\n"; sed -i '/Hello from/d' ~/.bashrc

printf "\n"
read -p "Work done. Press enter to exit and reboot."
exit
umount -a
reboot
