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
# wget https://bit.ly/2ZoJvnW -O arch.sh

# to enable ssh connection to livecd install
# set password for root user
# passwd
# systemctl start sshd.service

# rm arch*.sh; curl https://raw.githubusercontent.com/georgeabr/arch/master/arch.sh > arch.sh; chmod +x arch.sh

# parted examples
# https://wiki.archlinux.org/index.php/Parted#UEFI/GPT_examples

# will check if any arguments were passed to the program
if [ $# -lt 3 ]
    then
	printf "No arguments supplied. Provide 3 arguments (sda1 sda2 sda3):\n1. UEFI drive\n2. root drive\n3. swap drive\n";
	printf "Partitions should already exist on the disk, will be reused.\n\n";
	fdisk -l;
	exit 0;
#    else
#	echo "$#"
fi

# delete line after executing it; good for first-time config
# printf "Hello from bash\n"; sed -i '/Hello from/d' ~/.bashrc

uefi_drive="/dev/$1"
root_drive="/dev/$2"
swap_drive="/dev/$3"

if [ $# -ge 3 ]
then
	# echo "Script has at least 3 arguments:\n$1, $2, $3"
	printf "Will use\n$uefi_drive for UEFI\n$root_drive for root\n$swap_drive for swap\n"
fi


go_ahead()
{
	printf "\nPart 1 - Initial Arch bootstrap/installation.\n";
	# printf "Creating new GPT table\n";
	# parted -s /dev/sda mklabel gpt
	
	# printf "Creating UEFI partition - 128M.\n"
	# parted -s /dev/sda mkpart primary FAT32 1 128MiB
	# parted -s /dev/sda set 1 esp on
	# printf "Formatting UEFI partition.\n"
	# mkfs.fat -F32 /dev/sda1

	# printf "Creating SWAP partition - 1GB.\n";
	# parted -s /dev/sda mkpart primary linux-swap 128MiB 1129MiB
	# printf "Formatting SWAP partition.\n"	
	mkswap /dev/sda2
	printf "Activating SWAP partition.\n"
	swapon $swap_drive
	
	printf "Formatting ROOT partition as ext4.\n";
	# parted -s /dev/sda mkpart primary ext4 1129MiB 100%
	# printf "Formatting ROOT parition as ext4.\n"
	mkfs.ext4 $root_drive

	printf "Mounting UEFI, ROOT partitions.\n"
	mount $root_drive /mnt
	mkdir -p /mnt/boot/EFI
	mount $uefi_drive /mnt/boot/EFI

	printf "Setting systemd NTP clock sync.\n"
	timedatectl set-ntp true

	printf "Updating Arch package keyring.\n"
	pacman -Sy --noconfirm archlinux-keyring

	printf "Installing base Arch packages.\n"
	pacstrap /mnt base base-devel

	printf "Creating fstab with root/swap/UEFI.\n"
	genfstab -U /mnt >> /mnt/etc/fstab
	
	printf "Chrooting into installation.\n"
	curl https://raw.githubusercontent.com/georgeabr/arch/master/arch-2.sh > arch-2.sh; chmod +x arch-2.sh; cp ./arch-2.sh /mnt; arch-chroot /mnt /bin/bash -c "./arch-2.sh"
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
