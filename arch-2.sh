#!/bin/bash

printf "\n\nPart 2 - continuing install/customisation.\nConfiguring locale to London/UK.\n"
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc --utc
grep -rl "#en_GB.UTF-8 UTF-8" /etc/locale.gen | xargs sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g'
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8
# localectl list-keymaps - use to list available keymaps
echo "KEYMAP=uk" > /etc/vconsole.conf
locale-gen

printf "\nConfiguring hostname\n."
echo archie > /etc/hostname
	
# printf "Enabling DHCP.\n"
# systemctl enable dhcpcd.service

printf "\nEnabling SSH.\n"
pacman -Sy --noconfirm openssh
systemctl enable sshd.service

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

printf "\nInstalling GRUB.\n"
pacman -Sy --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi  --bootloader-id=grub_uefi --efi-directory=/boot/EFI/ --bootloader-id="Arch Linux"
# single quote ' is '\''
grep -rl " quiet" /etc/default/grub | xargs sed -i 's/ quiet/ quiet mitigations=off /g'
grub-mkconfig -o /boot/grub/grub.cfg
mkinitcpio -p linux

printf "\nEnabling multilib.\n"
pacman_file="/etc/pacman.conf"; printf "\n\n# Enabling multilib." >> $pacman_file; \
	printf "\n[multilib]" >> $pacman_file; printf "\nInclude = /etc/pacman.d/mirrorlist\n" >> $pacman_file

printf "\nInstalling Intel video drivers, KDE Plasma, fonts.\n"
pacman -Sy --noconfirm zram-generator
pacman -Sy --noconfirm perf
pacman -Sy --noconfirm intel-media-driver libva-utils
pacman -Sy --noconfirm plasma-meta plasma-workspace 
pacman -Sy --noconfirm ark dolphin kate konsole sddm gwenview spectacle
pacman -Sy --noconfirm pipewire pipewire-alsa pipewire-pulse pavucontrol
pacman -Sy --noconfirm mc nano vim htop wget iwd smartmontools xdg-utils iotop-c less man-pages
pacman -Sy --noconfirm ttf-dejavu ttf-roboto-mono ttf-bitstream-vera ttf-liberation noto-fonts
pacman -Sy --noconfirm git networkmanager networkmanager-openvpn nm-connection-editor network-manager-applet
pacman -Sy --noconfirm firefox unzip unrar aria2

# Enable ZRAM
printf "\nEnabling ZRAM.\n"
printf "[zram0]\n" > /etc/systemd/zram-generator.conf
systemctl enable systemd-zram-setup@zram0.service

systemctl enable sddm.service
systemctl enable NetworkManager
systemctl start NetworkManager

# do user creation after everything is installed
printf "\nEnter <root> user password....\n"
passwd root
printf "\nAdding user <george>, sudo permission.\n"
useradd -m -G wheel -s /bin/bash george
printf "Enter password for user <george> ...\n"
passwd george


# does not work from chroot
# timedatectl set-ntp true
# to be done by user, copy file to root, execute as regular user

mkhomedir_helper george
# printf "\041" - meaning !
#!/bin/bash

# ~/.config/gtk-4.0/settings.ini
mkdir /home/george/.config; chown george:george /home/george/.config
mkdir /home/george/.config/gtk-4.0;
printf "[Settings]" > /home/george/.config/gtk-4.0/settings.ini
printf "\ngtk-cursor-blink = 0" >> /home/george/.config/gtk-4.0/settings.ini
chown george:george /home/george/.config/gtk-4.0/settings.ini

# ~/.config/gtk-3.0/settings.ini
mkdir /home/george/.config/gtk-3.0; 
printf "[Settings]" > /home/george/.config/gtk-3.0/settings.ini
printf "\ngtk-cursor-blink = 0" >> /home/george/.config/gtk-3.0/settings.ini
# consistency for all GTK3 apps, including Firefox
#printf "\ngtk-cursor-theme-name = Adwaita" >> /home/george/.config/gtk-3.0/settings.ini
#printf "\ngtk-cursor-theme-size = 32" >> /home/george/.config/gtk-3.0/settings.ini
chown george:george /home/george/.config/gtk-3.0/settings.ini

# for gtk2, including under kde
printf "\ngtk-cursor-blink = 0" >> /home/george/.gtkrc-2.0
printf "\ngtk-cursor-blink = 0" >> /home/george/.gtkrc-2.0-kde
chown george:george /home/george/.gtkrc-2.0
chown george:george /home/george/.gtkrc-2.0-kde

# install trizen on first user console login
home_script="/home/george/welcome.sh"; 
printf "#\041/bin/bash\n" > $home_script; 
printf "\necho This script will tweak QT/GTK apps, NTP sync and UK keyboard layout.\n" >> $home_script;
printf "\necho It will also install <trizen> for AUR packages.\n" >> $home_script;
printf "\necho You should log off and on again for KDE cursor blink deactivation.\n" >> $home_script;
printf "\nread -p \"Press a key. This script should be run after you log in to KDE.\"" >> $home_script;
printf "\necho [KDE] >> ~/.config/kdeglobals" >> $home_script;
printf "\necho CursorBlinkRate=0 >> ~/.config/kdeglobals" >> $home_script;
printf "\nsudo timedatectl set-ntp true" >> $home_script
printf "\nsudo localectl set-x11-keymap gb pc105" >> $home_script
printf "\ngpg --recv-keys C1A60EACE707FDA5" >> $home_script
printf "\ngit clone https://aur.archlinux.org/trizen.git" >> $home_script
printf "\ncd trizen" >> $home_script
printf "\nmakepkg -si" >> $home_script

chown george:george /home/george/welcome.sh
chmod +x /home/george/welcome.sh
printf "./welcome.sh; sed -i '/welcome/d' ~/.bashrc" >> /home/george/.bashrc
printf "\n" >> /home/george/.bashrc

printf "\n"
read -p "Installation completed. Press <Enter> to exit and reboot."
exit
umount -a
reboot
