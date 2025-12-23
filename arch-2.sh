#!/bin/bash

hostname="$1"
username="$2"

# Bootstrap the GPG keyring
rm -rf /etc/pacman.d/gnupg
mkdir -m700 /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux

printf "\nEnabling multilib.\n"
pacman_file="/etc/pacman.conf"; printf "\n\n# Enabling multilib." >> $pacman_file; \
	printf "\n[multilib]" >> $pacman_file; printf "\nInclude = /etc/pacman.d/mirrorlist\n" >> $pacman_file

# Now update and install everything else with pacman
pacman -Syyu --noconfirm

printf "\n\nPart 2 - continuing install/customisation.\nConfiguring locale to London/UK.\n"
pacman -S --noconfirm terminus-font
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc --utc
grep -rl "#en_GB.UTF-8 UTF-8" /etc/locale.gen | xargs sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g'
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8
# localectl list-keymaps - use to list available keymaps
echo "KEYMAP=uk" >> /etc/vconsole.conf
echo "XKBLAYOUT=gb" >> /etc/vconsole.conf
echo "FONT=ter-922b" >> /etc/vconsole.conf

locale-gen

printf "\nConfiguring hostname\n"
echo $hostname > /etc/hostname
	
# printf "Enabling DHCP.\n"
# systemctl enable dhcpcd.service

printf "\nEnabling SSH.\n"
pacman -S --noconfirm openssh
systemctl enable sshd.service

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

printf "\nInstalling GRUB.\n"
pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools
# grub-install --target=x86_64-efi  --bootloader-id=grub_uefi --efi-directory=/boot/EFI/ --bootloader-id="ArchLinux"
grub-install --target=x86_64-efi --efi-directory=/boot/EFI/ --bootloader-id="ArchLinux-$hostname"
# single quote ' is '\''
grep -rl " quiet" /etc/default/grub | xargs sed -i 's/ quiet/ quiet mitigations=off /g'
grub-mkconfig -o /boot/grub/grub.cfg
mkinitcpio -p linux

printf "\nInstalling Intel video drivers, KDE Plasma, fonts.\n"
pacman -S --noconfirm zram-generator
pacman -S --noconfirm perf strace 
pacman -S --noconfirm intel-media-driver libva-utils
pacman -S --noconfirm plasma-meta plasma-x11-session kwin-x11 plasma-workspace sddm
pacman -S --noconfirm ark dolphin kate konsole gwenview
pacman -S --noconfirm pipewire-alsa pavucontrol
pacman -S --noconfirm mc nano vim htop wget iwd iotop-c less man-pages mandoc bc
pacman -S --noconfirm ttf-dejavu ttf-roboto-mono ttf-bitstream-vera ttf-liberation ttf-nerd-fonts-symbols-mono
pacman -S --noconfirm git networkmanager-openvpn nm-connection-editor network-manager-applet
pacman -S --noconfirm firefox unzip unrar aria2 7zip

### wezterm
# URL of the package to download
#PACKAGE_URL="https://github.com/georgeabr/arch-iso/releases/download/20250728_142256/wezterm-git-20250725.073938.dd6e5bd2-1-x86_64.pkg.tar.zst"
PACKAGE_URL="https://github.com/georgeabr/arch-iso/releases/download/20251223_112125/wezterm-git-20251223.105516.d3b0fdad4-1-x86_64.pkg.tar.zst"


# create a temporary directory
TMPDIR=$(mktemp -d)
PACKAGE_FILE="${TMPDIR}/$(basename "${PACKAGE_URL}")"

# download the package
echo "Downloading ${PACKAGE_URL}"
curl -L -o "${PACKAGE_FILE}" "${PACKAGE_URL}"

# install the downloaded package and its missing dependencies
echo "Installing ${PACKAGE_FILE}"
sudo pacman -U --noconfirm "${PACKAGE_FILE}"

# cleanup
rm -rf "${TMPDIR}"

pacman -Q wezterm-git
echo "wezterm-git package installed."
### wezterm

### trizen AUR downloader
# URL of the package to download
PACKAGE_URL="https://github.com/georgeabr/arch-iso/releases/download/trizen-git/trizen-1.1.68-1-any.pkg.tar.zst"

# create a temporary directory
TMPDIR=$(mktemp -d)
PACKAGE_FILE="${TMPDIR}/$(basename "${PACKAGE_URL}")"

# download the package
echo "Downloading ${PACKAGE_URL}"
curl -L -o "${PACKAGE_FILE}" "${PACKAGE_URL}"

# install the downloaded package and its missing dependencies
echo "Installing ${PACKAGE_FILE}"
sudo pacman -U --noconfirm "${PACKAGE_FILE}"

# cleanup
rm -rf "${TMPDIR}"

pacman -Q trizen
echo "trizen package installed."
### trizen AUR downloader


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
echo ">> All done. Exit chroot and reboot for changes to take effect."
### NTP and UK keyboard layout


### Disable QT/SDDM cursor blink globally, add UK keyboard layout
# Ensure target directories exist
mkdir -p /etc/xdg /etc/sddm.conf.d

# 1) system-wide X11 layout (kxkbrc)
echo '[Layout]'                        > /etc/xdg/kxkbrc
echo 'Enabled=true'                   >> /etc/xdg/kxkbrc
echo 'LayoutList=gb'                  >> /etc/xdg/kxkbrc
echo 'PerWindow=false'                >> /etc/xdg/kxkbrc
echo 'PerApplication=false'           >> /etc/xdg/kxkbrc
echo ''                               >> /etc/xdg/kxkbrc
echo '[Options]'                      >> /etc/xdg/kxkbrc
# echo 'grp:alt_shift_toggle'        >> /etc/xdg/kxkbrc  # optional XKB options
chmod 644 /etc/xdg/kxkbrc

# 2) system-wide KDE input settings (kcminputrc) for Plasma6
echo '[Keyboard]'                     > /etc/xdg/kcminputrc
echo 'Layout=gb'                      >> /etc/xdg/kcminputrc
echo 'Model=pc105'                    >> /etc/xdg/kcminputrc
echo 'Variant='                       >> /etc/xdg/kcminputrc
echo 'Options='                       >> /etc/xdg/kcminputrc
chmod 644 /etc/xdg/kcminputrc

# 3) SDDM login screen layout (keyboard.conf)
echo '[General]'                      > /etc/sddm.conf.d/keyboard.conf
echo 'InputMethod=none'               >> /etc/sddm.conf.d/keyboard.conf
echo ''                               >> /etc/sddm.conf.d/keyboard.conf
echo '[Keyboard]'                     >> /etc/sddm.conf.d/keyboard.conf
echo 'Layout=gb'                      >> /etc/sddm.conf.d/keyboard.conf
echo 'Model=pc105'                    >> /etc/sddm.conf.d/keyboard.conf
chmod 644 /etc/sddm.conf.d/keyboard.conf

# 4) Disable cursor blink system-wide (kdeglobals)
echo '[General]'                      > /etc/xdg/kdeglobals
echo 'CursorBlinkRate=0'              >> /etc/xdg/kdeglobals
echo '[KDE]'                          >> /etc/xdg/kdeglobals
echo 'CursorBlinkRate=0'              >> /etc/xdg/kdeglobals
echo 'AnimationDurationFactor=0'      >> /etc/xdg/kdeglobals

chmod 644 /etc/xdg/kdeglobals

echo "System-wide UK keyboard layout configured for Plasma6 & SDDM, cursor blink disabled."
### Disable QT/SDDM cursor blink globally, add UK keyboard layout


### GTK 3/4 cursor blink
# Create GTK3 and GTK4 system‐wide config dirs
mkdir -p /etc/gtk-3.0 /etc/gtk-4.0

# 1) Disable cursor blink in GTK3 apps
echo '[Settings]'                         > /etc/gtk-3.0/settings.ini
echo 'gtk-cursor-blink = false'          >> /etc/gtk-3.0/settings.ini
echo 'gtk-cursor-blink-timeout = 0'      >> /etc/gtk-3.0/settings.ini
chmod 644 /etc/gtk-3.0/settings.ini

# 2) Disable cursor blink in GTK4 apps
echo '[Settings]'                         > /etc/gtk-4.0/settings.ini
echo 'gtk-cursor-blink = false'          >> /etc/gtk-4.0/settings.ini
echo 'gtk-cursor-blink-timeout = 0'      >> /etc/gtk-4.0/settings.ini
chmod 644 /etc/gtk-4.0/settings.ini

echo "GTK3/4 cursor blink globally disabled."
### GTK 3/4 cursor blink


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

# Not needed, `useradd -m` does it
# mkhomedir_helper $username
# printf "\041" - meaning !

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

# Ensure user's config directory exists
mkdir -p /home/$username/.config
chown $username:$username /home/$username/.config

# Write keyboard layout config (kxkbrc) for KDE sessions
echo '[Layout]'                                > /home/$username/.config/kxkbrc
echo 'Use=true'                                >> /home/$username/.config/kxkbrc
echo 'LayoutList=gb'                           >> /home/$username/.config/kxkbrc
echo 'Options='                                >> /home/$username/.config/kxkbrc
echo 'Model=pc105'                             >> /home/$username/.config/kxkbrc
echo 'Variant='                                >> /home/$username/.config/kxkbrc

# Set permissions
chown $username:$username /home/$username/.config/kxkbrc
chmod 644 /home/$username/.config/kxkbrc

echo '# Better icon scaling in KDE' >> /home/$username/.profile
echo 'export QT_SCALE_FACTOR_ROUNDING_POLICY=Round' >> /home/$username/.profile

# Create or update kdeglobals to disable cursor blink
echo 'echo '[General]'                        >> /home/$username/.config/kdeglobals
echo 'AccentColor=104,107,111'           >> /home/$username/.config/kdeglobals
# echo 'ColorScheme=BreezeDark1'           >> /home/$username/.config/kdeglobals
echo 'ColorScheme=BreezeDark-new-darker'  >> /home/$username/.config/kdeglobals

echo '[KDE]'                        >> /home/$username/.config/kdeglobals
echo 'CursorBlinkRate=0'           >> /home/$username/.config/kdeglobals
echo 'AnimationDurationFactor=0'           >> /home/$username/.config/kdeglobals

# Set ownership and permission
chown $username:$username /home/$username/.config/kdeglobals
chmod 644 /home/$username/.config/kdeglobals

echo '[Keyboard]'                    >> /home/$username/.config/kcminputrc
echo 'NumLock=0'                     >> /home/$username/.config/kcminputrc

echo '[Mouse]'                        >> /home/$username/.config/kcminputrc
echo 'cursorSize=40'                  >> /home/$username/.config/kcminputrc
echo 'cursorTheme=XCursor-Pro-Dark'   >> /home/$username/.config/kcminputrc

# Set ownership and permission
chown $username:$username /home/$username/.config/kcminputrc
chmod 644 /home/$username/.config/kcminputrc

echo "contents of kcminputrc"
cat /home/$username/.config/kcminputrc
echo; echo "contents of kdeglobals"
cat /home/$username/.config/kdeglobals

# --- Start of user's requested KDE/XCursor configuration ---
printf "\nConfiguring KDE colour schemes and XCursor themes...\n"

# Dark colour schemes for KDE
mkdir -p /home/$username/.local/share/color-schemes
chown $username:$username /home/$username/.local/share/color-schemes/
curl -s -L -o /home/$username/.local/share/color-schemes/BreezeDark1.colors \
	https://raw.githubusercontent.com/georgeabr/linux-configs/refs/heads/master/BreezeDark1.colors
curl -s -L -o /home/$username/.local/share/color-schemes/BreezeDark-new-darker.colors \
	https://raw.githubusercontent.com/georgeabr/linux-configs/refs/heads/master/BreezeDark-new-darker.colors
curl -s -L -o /home/$username/.local/share/color-schemes/Chocula-darker-warm.colors \
 	https://raw.githubusercontent.com/georgeabr/linux-configs/refs/heads/master/Chocula-darker-warm.colors
curl -s -L -o /home/$username/.local/share/color-schemes/Chocula-darker.colors \
 	https://raw.githubusercontent.com/georgeabr/linux-configs/refs/heads/master/Chocula-darker.colors
  
chown $username:$username /home/$username/.local/share/color-schemes/BreezeDark1.colors
chown $username:$username /home/$username/.local/share/color-schemes/BreezeDark-new-darker.colors
chown $username:$username /home/$username/.local/share/color-schemes/Chocula-darker-warm.colors
chown $username:$username /home/$username/.local/share/color-schemes/Chocula-darker.colors

ls -lha /home/$username/.local/share/color-schemes/

mkdir -p /home/$username/.icons
chown $username:$username /home/$username/.icons/
curl -s -L -o /home/$username/XCursor-Pro-Dark.tar.xz \
	https://github.com/ful1e5/XCursor-pro/releases/download/v2.0.2/XCursor-Pro-Dark.tar.xz
# Corrected GitLab raw URL for Hackneyed-Dark
curl -s -L -o /home/$username/Hackneyed-Dark-36px-0.9.3-right-handed.tar.bz2 \
	https://github.com/georgeabr/linux-configs/raw/refs/heads/master/Hackneyed-Dark-36px-0.9.3-right-handed.tar.bz2

# extract directly into .icons
tar -xf /home/$username/XCursor-Pro-Dark.tar.xz -C "/home/$username/.icons"
rm /home/$username/XCursor-Pro-Dark.tar.xz
tar -xf /home/$username/Hackneyed-Dark-36px-0.9.3-right-handed.tar.bz2 -C "/home/$username/.icons"
rm /home/$username/Hackneyed-Dark-36px-0.9.3-right-handed.tar.bz2

# fix ownership of the unpacked theme
chown -R "$username":"$username" "/home/$username/.icons/XCursor-Pro-Dark"
chown -R "$username":"$username" "/home/$username/.icons/Hackneyed-Dark-36px"

ls -lha /home/$username/.icons/

# htop tweaking
mkdir -p /home/$username/.config/htop
curl -s -L -o /home/$username/.config/htop/htoprc \
	https://raw.githubusercontent.com/georgeabr/linux-configs/refs/heads/master/v5/.config/htop/htoprc

# Making sure the user owns their home folder recursively
chown -R $username:$username "/home/$username/"

printf "\nInstallation completed. Pleas reboot and log into KDE.\n"
