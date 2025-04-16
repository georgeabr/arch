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

# TO RUN THIS FROM AN ARCH LINUX ISO
# pacman -Sy wget; bash
# wget https://raw.githubusercontent.com/georgeabr/arch/refs/heads/master/arch.sh -O arch.sh; chmod +x arch.sh
# wget https://bit.ly/2ZoJvnW -O arch.sh; chmod +x arch.sh

# TO RUN THIS SCRIPT WITH LOGGING ENABLED
# ./arch.sh 2>&1 | tee combined.log

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
    	printf "Welcome to the Arch Linux installation script.\n\n";
	printf "No arguments supplied. Provide 3 numbers separated by space (1 3 5):\n1. UEFI partition\n2. root (/) partition \n3. swap partition\n";
 	printf "Use a partitioning program such as <cfdisk> to set up partitions.\n";
	printf "Partitions should already exist on the disk (including swap), will be reused.\n";
 	printf "Take a look below for the partitions on your current disks.\n";
  	printf "You should use/create partitions on </dev/nvme0n1> or </dev/sda>.\n"
   	printf "\n";
	fdisk -l;
	exit 1;
#    else
#	echo "$#"
fi

# delete line after executing it; good for first-time config
# printf "Hello from bash\n"; sed -i '/Hello from/d' ~/.bashrc

# get list of partitions that start with '/dev/'
partitions=($(fdisk -l | awk '/Disk \/dev\// { disk = $2; sub(/:$/, "", disk) }/^\/dev\// && !/Disklabel/ { print disk "=" $1 }' | grep -v '^=' | cut -d '=' -f 2))
# printf "%s\n" "${partitions[@]}"
uefi_drive="${partitions[$1-1]}"
root_drive="${partitions[$2-1]}"
swap_drive="${partitions[$3-1]}"

if [ $# -ge 3 ]
then
	# echo "Script has at least 3 arguments:\n$1, $2, $3"
	printf "\nWill use the below partitions:\n\n$uefi_drive for UEFI\n"
	lsblk -o NAME,FSTYPE,SIZE,mountpoints "$uefi_drive"
 	printf "\n$root_drive for root\n"
	lsblk -o NAME,FSTYPE,SIZE,mountpoints "$root_drive"
	printf "\n$swap_drive for swap\n"
	lsblk -o NAME,FSTYPE,SIZE,mountpoints "$swap_drive"
	printf "\n"
	fdisk -l|grep -E "(Device|$uefi_drive|$root_drive|$swap_drive)"
	printf "\n"
fi

read -p "Do you wish to continue? (Y\y to continue, any other input to stop): " response

if ! [[ "$response" == "y" ]] && ! [[ "$response" == "Y" ]] then
  printf "\nExiting script.\n"
  exit 1
fi



printf "\nWill continue to installing Arch Linux.\n"
# exit 0;

go_ahead()
{
	# printf "Using UK mirrors\n"
	# pacman_file="/etc/pacman.d/mirrorlist"; 
	# printf "Server = http://archlinux.uk.mirror.allworldit.com/archlinux/\$repo/os/\$arch" > $pacman_file;
	
	#pacman -Sy --noconfirm pacman-contrib
 	printf "\nAdding mirrors, please be patient.\n"
  	# will not rank mirrors, it takes too long
	# curl -s "https://archlinux.org/mirrorlist/?&country=GB&protocol=http&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist 
 	# curl -s "https://archlinux.org/mirrorlist/?&country=GB&protocol=http&protocol=https&use_mirror_status=on" \
  	# | sed -e 's/^#Server/Server/' -e '/^#/d' \
   	# | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

    	curl -s "https://archlinux.org/mirrorlist/?&country=GB&protocol=http&protocol=https&use_mirror_status=on" \
  	| sed -e 's/^#Server/Server/' -e '/^#/d' \
   	> /etc/pacman.d/mirrorlist
	
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
	# mkswap $swap_drive
	printf "\nActivating SWAP partition.\n"
	swapon $swap_drive > /dev/null 2>&1;
	 if [[ $? -ne 0 ]]; then
  		printf "\nFormatting and activating swap file.";
    		mkswap $swap_drive > /dev/null 2>&1;
      		swapon $swap_drive > /dev/null 2>&1;
	else
    		printf "\nSwap file has been enabled."
	fi

	
	printf "\nFormatting ROOT partition as ext4.\n";
	# parted -s /dev/sda mkpart primary ext4 1129MiB 100%
	# printf "Formatting ROOT parition as ext4.\n"
	mkfs.ext4 $root_drive

	printf "\nMounting UEFI, ROOT partitions.\n"
	mount $root_drive /mnt
	mkdir -p /mnt/boot/EFI
	mount $uefi_drive /mnt/boot/EFI

	printf "\nSetting systemd NTP clock sync.\n"
	timedatectl set-ntp true

	printf "\nUpdating Arch package keyring.\n"
	pacman -Sy --noconfirm archlinux-keyring

	printf "\nInstalling base Arch packages.\n"
	# install LTS kernel for now, bug with ELAN touchpad
	pacstrap /mnt linux linux-headers base base-devel linux-firmware intel-ucode bash


	printf "\nCreating fstab with root/swap/UEFI.\n"
	genfstab -U /mnt >> /mnt/etc/fstab
	
	printf "\nChrooting into installation.\n"
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

#echo ""
go_ahead
#read -r -p "Are you sure? [y/N] " response
#case "$response" in
#    [yY][eE][sS]|[yY]) 
#        go_ahead
#        ;;
#    *)
#        leave_now
#        ;;
#esac
