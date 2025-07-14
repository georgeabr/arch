#!/bin/bash

hostname="$1"
username="$2"

printf "\n\nPart 2 - continuing install/customisation.\nConfiguring locale to London/UK.\n"
pacman -Sy --noconfirm terminus-font
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc --utc
grep -rl "#en_GB.UTF-8 UTF-8" /etc/locale.gen | xargs sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g'
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8
# localectl list-keymaps - use to list available keymaps
echo "KEYMAP=uk" > /etc/vconsole.conf
echo "XKBLAYOUT=gb" > /etc/vconsole.conf
echo "FONT=ter-922b" > /etc/vconsole.conf

locale-gen

printf "\nConfiguring hostname\n"
echo $hostname > /etc/hostname
	
# printf "Enabling DHCP.\n"
# systemctl enable dhcpcd.service

printf "\nEnabling SSH.\n"
pacman -Sy --noconfirm openssh
systemctl enable sshd.service

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

printf "\nInstalling GRUB.\n"
pacman -Sy --noconfirm grub efibootmgr dosfstools os-prober mtools
# grub-install --target=x86_64-efi  --bootloader-id=grub_uefi --efi-directory=/boot/EFI/ --bootloader-id="ArchLinux"
grub-install --target=x86_64-efi --efi-directory=/boot/EFI/ --bootloader-id="ArchLinux"
# single quote ' is '\''
grep -rl " quiet" /etc/default/grub | xargs sed -i 's/ quiet/ quiet mitigations=off /g'
grub-mkconfig -o /boot/grub/grub.cfg
mkinitcpio -p linux

printf "\nEnabling multilib.\n"
pacman_file="/etc/pacman.conf"; printf "\n\n# Enabling multilib." >> $pacman_file; \
	printf "\n[multilib]" >> $pacman_file; printf "\nInclude = /etc/pacman.d/mirrorlist\n" >> $pacman_file

printf "\nInstalling Intel video drivers, KDE Plasma, fonts.\n"
pacman -Sy --noconfirm zram-generator
pacman -Sy --noconfirm perf strace 
pacman -Sy --noconfirm intel-media-driver libva-utils
pacman -Sy --noconfirm plasma-meta plasma-x11-session kwin-x11 plasma-workspace 
pacman -Sy --noconfirm ark dolphin kate konsole gwenview spectacle
pacman -Sy --noconfirm pipewire-alsa pavucontrol
pacman -Sy --noconfirm mc nano vim htop wget iwd iotop-c less man-pages mandoc bc
pacman -Sy --noconfirm ttf-dejavu ttf-roboto-mono ttf-bitstream-vera ttf-liberation ttf-nerd-fonts-symbols-mono
pacman -Sy --noconfirm git networkmanager-openvpn nm-connection-editor network-manager-applet
pacman -Sy --noconfirm firefox unzip unrar aria2 7zip

### wezterm
# URL of the package to download
PACKAGE_URL="https://github.com/georgeabr/arch-iso/releases/download/20250714_123644/wezterm-git-20250713.135109.85c587f9-1-x86_64.pkg.tar.zst"

# create a temporary directory
TMPDIR=$(mktemp -d)
PACKAGE_FILE="${TMPDIR}/$(basename "${PACKAGE_URL}")"

# download the package
echo "Downloading ${PACKAGE_URL}"
curl -L -o "${PACKAGE_FILE}" "${PACKAGE_URL}"

# synchronize package databases
echo "Synchronizing package databases"
sudo pacman -Sy --noconfirm

# install the downloaded package and its missing dependencies
echo "Installing ${PACKAGE_FILE}"
sudo pacman -U --noconfirm --needed --syncdeps "${PACKAGE_FILE}"

# cleanup
rm -rf "${TMPDIR}"

echo "wezterm-git package installed."
### wezterm


### Cousine Nerd Font
# 1) Configuration
REPO="ryanoasis/nerd-fonts"
FONT="Cousine"
INSTALL_DIR="/usr/local/share/fonts/${FONT}NerdFont"

# 2) Fetch latest release JSON and extract the ZIP URL for Cousine
echo "Looking up latest ${FONT} Nerd Font release"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
ASSET_URL=$(
  curl -s "${API_URL}" \
    | grep -E 'browser_download_url.*Cousine.*\.zip"' \
    | head -n1 \
    | cut -d '"' -f4
)

if [[ -z "$ASSET_URL" ]]; then
  echo "Failed to find a download URL for ${FONT}.zip" >&2
  exit 1
fi

echo "Found download URL: $ASSET_URL"

# 3) Download the ZIP to a temp dir
TMPDIR=$(mktemp -d)
ZIPFILE="${TMPDIR}/${FONT}.zip"
echo "Downloading ZIP to $ZIPFILE"
curl -L -o "$ZIPFILE" "$ASSET_URL"

# 4) Unpack into the system fonts directory
echo "Installing into $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo unzip -o "$ZIPFILE" -d "$INSTALL_DIR" >/dev/null

# 5) Refresh font cache
echo "Refreshing font cache"
sudo fc-cache -f -v >/dev/null

# 6) Cleanup
rm -rf "$TMPDIR"

echo "${FONT} Nerd Font installed system-wide in $INSTALL_DIR"
### Cousine Nerd Font



### NTP and UK keyboard layout
#
# enable-ntp-keymap.sh
# Run inside an Arch chroot (e.g. arch-chroot /mnt /root/enable-ntp-keymap.sh)
#

# full paths to files and binaries
TIMESYNCD_CONF="/etc/systemd/timesyncd.conf"
SERVICE_UNIT="/usr/lib/systemd/system/systemd-timesyncd.service"
WANTS_DIR="/etc/systemd/system/multi-user.target.wants"
WANTS_LINK="${WANTS_DIR}/systemd-timesyncd.service"
LOCALCTL_BIN="/usr/bin/localectl"

# keyboard layout settings
KEYMAP="gb"
KEYBOARD_MODEL="pc105"

echo "1) Configuring NTP servers in ${TIMESYNCD_CONF}"
mkdir -p "${WANTS_DIR}"
sed -E -i 's@^#?NTP=.*@NTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org@' \
    "${TIMESYNCD_CONF}"

echo "2) Enabling systemd-timesyncd.service at boot"
ln -sf "${SERVICE_UNIT}" "${WANTS_LINK}"

echo "3) Verifying NTP configuration"
grep '^NTP=' "${TIMESYNCD_CONF}"
ls -l "${WANTS_LINK}"

echo ""
echo "4) Setting X11 keymap to ${KEYMAP} / ${KEYBOARD_MODEL}"
"${LOCALCTL_BIN}" set-x11-keymap "${KEYMAP}" "${KEYBOARD_MODEL}"

echo ""
echo "5) Displaying current locale & keymap status"
"${LOCALCTL_BIN}" status

echo ""
echo ">> All done. Exit chroot and reboot for changes to take effect."
### NTP and UK keyboard layout


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
printf "\nAdding user <$username>, sudo permission.\n"
useradd -m -G wheel -s /bin/bash $username
printf "Enter password for user <$username> ...\n"
passwd $username


# does not work from chroot
# timedatectl set-ntp true
# to be done by user, copy file to root, execute as regular user

mkhomedir_helper $username
# printf "\041" - meaning !
#!/bin/bash

# ~/.config/gtk-4.0/settings.ini
mkdir /home/$username/.config; chown $username:$username /home/$username/.config
mkdir /home/$username/.config/gtk-4.0;
printf "[Settings]" > /home/$username/.config/gtk-4.0/settings.ini
printf "\ngtk-cursor-blink = 0\n" >> /home/$username/.config/gtk-4.0/settings.ini
chown $username:$username /home/$username/.config/gtk-4.0/settings.ini

# ~/.config/gtk-3.0/settings.ini
mkdir /home/$username/.config/gtk-3.0; 
printf "[Settings]" > /home/$username/.config/gtk-3.0/settings.ini
printf "\ngtk-cursor-blink = 0\n" >> /home/$username/.config/gtk-3.0/settings.ini
# consistency for all GTK3 apps, including Firefox
#printf "\ngtk-cursor-theme-name = Adwaita" >> /home/george/.config/gtk-3.0/settings.ini
#printf "\ngtk-cursor-theme-size = 32" >> /home/george/.config/gtk-3.0/settings.ini
chown $username:$username /home/$username/.config/gtk-3.0/settings.ini
curl -s -L -o /home/$username/.vimrc https://raw.githubusercontent.com/georgeabr/linux-configs/refs/heads/master/.vimrc
curl -s -L -o /home/$username/.wezterm.lua https://raw.githubusercontent.com/georgeabr/linux-configs/refs/heads/master/.wezterm.lua

chown $username:$username /home/$username/.vimrc
chown $username:$username /home/$username/.wezterm.lua

# for gtk2, including under kde
printf "\ngtk-cursor-blink = 0\n" >> /home/$username/.gtkrc-2.0
printf "\ngtk-cursor-blink = 0\n" >> /home/$username/.gtkrc-2.0-kde
chown $username:$username /home/$username/.gtkrc-2.0
chown $username:$username /home/$username/.gtkrc-2.0-kde

# install trizen on first user console login
home_script="/home/$username/welcome.sh"; 
printf "#\041/bin/bash\n" > $home_script; 
# printf "\necho This script will tweak QT/GTK apps, NTP sync and UK keyboard layout.\n" >> $home_script;
printf "\necho This script will tweak QT/GTK apps.\n" >> $home_script;
printf "\necho \"It will also install <trizen> for AUR packages.\"\n" >> $home_script;
printf "\necho You should log off and on again for KDE cursor blink deactivation.\n" >> $home_script;
printf "\necho \"Make sure you have a <working internet connection>.\"\n" >> $home_script;
printf "\nread -p \"Press a key. This script should be run after you log in to KDE.\"" >> $home_script;
printf "\necho [KDE] >> ~/.config/kdeglobals" >> $home_script;
printf "\necho CursorBlinkRate=0 >> ~/.config/kdeglobals" >> $home_script;
# printf "\nsudo timedatectl set-ntp true" >> $home_script
# printf "\nsudo localectl set-x11-keymap gb pc105" >> $home_script
# printf "\nsudo systemctl restart systemd-timesyncd" >> $home_script
# printf "\nsudo timedatectl set-ntp true" >> $home_script
printf "\ngpg --recv-keys C1A60EACE707FDA5" >> $home_script
printf "\ngit clone https://aur.archlinux.org/trizen.git" >> $home_script
printf "\ncd trizen" >> $home_script
printf "\nmakepkg -si" >> $home_script
# printf "\ntrizen wezterm" >> $home_script

chown $username:$username /home/$username/welcome.sh
chmod +x /home/$username/welcome.sh
printf "./welcome.sh; sed -i '/welcome/d' ~/.bashrc" >> /home/$username/.bashrc
printf "\n" >> /home/$username/.bashrc

printf "\nInstallation completed. Log into KDE and start konsole to complete setup.\n"
read -p "Press <Enter> to exit and reboot. "
exit
umount -a
reboot
