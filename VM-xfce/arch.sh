#!/bin/bash

# git clone https://github.com/georgeabr/arch.git
# git config --global user.email "email@gmail.com"
# git config --global user.name "georgeabr"

# to save passwords
# git config credential.helper store

# commit the code
# git add .; git commit -m "added"; git push -u origin master

# to download script from git
# https://raw.githubusercontent.com/georgeabr/arch/master/arch.sh
# or
# https://raw.githubusercontent.com/georgeabr/arch/master/arch.sh
# wget https://bit.ly/2PW4p8k -O arch.sh; chmod +x arch.sh

# to enable ssh connection to livecd install
# set password for root user
# passwd
# systemctl start sshd.service

# rm arch.sh; curl https://raw.githubusercontent.com/georgeabr/arch/master/VM-xfce/arch.sh > arch.sh; chmod +x arch.sh; ./arch.sh 1 2 3 4

# parted examples
# https://wiki.archlinux.org/index.php/Parted#UEFI/GPT_examples

# will check if any arguments were passed to the program
if [ $# -lt 3 ]
    then
	printf "No arguments supplied. Provide 3 arguments:\n1. UEFI drive\n2. root drive\n3. swap drive\n" 
exit 0
#    else
#	echo "$#"
fi

uefi_boot="/dev/$1"
root_drive="/dev/$2"
swap_drive="/dev/$3"

if [ $# -ge 3 ]
then
	# echo "Script has at least 3 arguments:\n$1, $2, $3"
	printf "Arch XFCE - ext4 - VM edition\n"
	printf "Will use\n$uefi_boot for UEFI\n$root_drive for root\n$swap_drive for swap\n"
fi


go_ahead()
{
	printf "Using UK mirrors\n"
	pacman -Sy --noconfirm pacman-contrib
	curl -s "https://www.archlinux.org/mirrorlist/?&country=GB&country=FR&country=NL&protocol=http&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist 
	# pacman_file="/etc/pacman.d/mirrorlist"; 
	# printf "Server = http://archlinux.uk.mirror.allworldit.com/archlinux/\$repo/os/\$arch\n" > $pacman_file;
	# printf "Server = http://mirror.bytemark.co.uk/archlinux/\$repo/os/\$arch\n" >> $pacman_file;
	
	printf "\nPart 1 - Initial disk formatting/bootstrap/installation.\n";
	printf "Creating new GPT table\n";
	parted -s /dev/sda mklabel gpt
	
	printf "Creating UEFI partition - 128M.\n"
	parted -s /dev/sda mkpart primary FAT32 1 128MiB
	parted -s /dev/sda set 1 esp on
	printf "Formatting UEFI partition.\n"
	mkfs.fat -F32 /dev/sda1

	printf "Creating SWAP partition - 1GB.\n";
	parted -s /dev/sda mkpart primary linux-swap 128MiB 1129MiB
	printf "Formatting SWAP partition.\n"	
	mkswap /dev/sda2
	printf "Activating SWAP partition.\n"
	swapon /dev/sda2
	
	printf "Creating ROOT partition - rest of the disk.\n";
	parted -s /dev/sda mkpart primary ext4 1129MiB 100%
	printf "Formatting ROOT parition as ext4.\n"
	mkfs.ext4 /dev/sda3

	printf "Mounting UEFI, ROOT partitions.\n"
	mount /dev/sda3 /mnt
	mkdir -p /mnt/boot/EFI
	mount /dev/sda1 /mnt/boot/EFI

	printf "Setting systemd NTP clock sync.\n"
	timedatectl set-ntp true

	printf "Updating Arch package keyring.\n"
	pacman -Sy --noconfirm archlinux-keyring

	printf "Installing base Arch packages.\n"
	pacstrap /mnt linux linux-headers base base-devel

	printf "Creating fstab with root/swap/UEFI.\n"
	genfstab -U /mnt >> /mnt/etc/fstab
	
	printf "Chrooting into installation.\n"
	curl https://raw.githubusercontent.com/georgeabr/arch/master/VM-xfce/arch-2.sh > arch-2.sh; chmod +x arch-2.sh; cp ./arch-2.sh /mnt; arch-chroot /mnt /bin/bash -c "./arch-2.sh"
	# arch-chroot /mnt

	
# #en_GB.UTF-8 UTF-8
# grep -rl "#en_GB.UTF-8 UTF-8" /etc/locale.gen | xargs sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g'
}

leave_now()
{
	printf "Will leave now!!\n";
}

# test

echo ""
read -r -p "Are you sure? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        go_ahead
        ;;
    *)
        leave_now
        ;;
esac
