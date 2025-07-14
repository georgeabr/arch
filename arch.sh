#!/bin/bash


# ——— start self-logging ———
timestamp=$(date +%Y%m%d_%H%M)
logfile="install-${timestamp}.log"
# redirect all output (stdout+stderr) into tee ⇒ logfile _and_ console
exec > >(tee -a "$logfile") 2>&1

# echo "==> Logging install run to $logfile"
# ————————————————

# git clone https://github.com/georgeabr/arch.git
# git config --global user.email "email@gmail.com"
# git config --global user.name "georgeabr"

# to save passwords
# git config credential.helper store

# commit the code
# git add .; git commit -m "added"; git push -u origin master

# TO RUN THIS FROM AN ARCH LINUX ISO
# bash
# curl -L -o arch.sh https://raw.githubusercontent.com/georgeabr/arch/refs/heads/master/arch.sh; chmod +x arch.sh
# curl -L -o arch.sh https://bit.ly/4lDqXHQ; chmod +x arch.sh

# TO RUN THIS SCRIPT WITH LOGGING ENABLED
# ./arch.sh 2>&1 | tee install-$(date +%Y%m%d_%H%M).log

# CONNECT VIA SSH FROM ANOTHER COMPUTER
# - set password for root user
# passwd
# - run the ssh command:
# ssh root@ip-address

# parted examples
# https://wiki.archlinux.org/index.php/Parted#UEFI/GPT_examples

hostname="arx"
username="george"
# can be ext4 or xfs
filesystem="ext4"

setfont /usr/share/kbd/consolefonts/ter-922n.psf.gz
loadkeys uk

# Function to check if a value is a positive number
is_positive_number() {
  [[ "$1" =~ ^[0-9]+$ ]] # Matches positive integers (no negative sign, no decimals)
}

show_instructions() {
    	printf "\nWelcome to the Arch Linux installation script.\n\n";
     	printf "This script will install Intel video drivers, KDE Plasma 6 and a few tools.\n";
        printf "It will create the user <$username> and add it to <sudoers>.\n";
      	printf "Hostname will be <$hostname>. Locale/language is set to UK.\n";
        printf "Root partition (/) filesystem will be <$filesystem>.\n";
	printf "You can customise these by editing this file.\n";       
	printf "\n";
	printf "You should provide 3 partition numbers separated by space (\e[1m$0 1 3 5\e[0m):\
 		\n1. UEFI partition\n2. root (/) partition \n3. swap partition\n";
 	printf "\nUse a partitioning program such as <cfdisk> to set up partitions first.\n";
      	printf "This script will install Arch \e[1mon the primary disk only.\e[0m\n";
  	printf "It will use partitions on </dev/nvme0n1> or </dev/sda> in that order.\n"
   	printf "The UEFI partition should already be present (from a Windows install).\n";
       	printf "The root (/) partition will be formatted, and the swap will be reused.\n";
 	printf "Take a look below for the partitions on your current disks.\n";
   	printf "\n";
    	fdisk -l|grep --color=never -E "(sda|nvm)"
	# fdisk -l;
}


start_install() {

	# not needed - pass the global parameters to this function
	#local uefi_index=$1
	#local root_index=$2
	#local swap_index=$3


	# get list of partitions that start with '/dev/'
	partitions=($(fdisk -l | awk '/Disk \/dev\// { disk = $2; sub(/:$/, "", disk) }\
		/^\/dev\// && !/Disklabel/ { print disk "=" $1 }' | grep -v '^=' | cut -d '=' -f 2))
	# printf "%s\n" "${partitions[@]}"
	uefi_part="${partitions[$(( $1 - 1 ))]}" 
	root_part="${partitions[$(( $2 - 1 ))]}" 
	swap_part="${partitions[$(( $3 - 1 ))]}"

	printf "\nThe Arch install script will use the settings:\n";
 	printf "%s\n" "* host name  = $hostname";
 	printf "%s\n" "* user name  = $username";
   	printf "%s\n" "* filesystem = $filesystem";

 
	printf "\nThe Arch install script will use the below partitions:\
	\n* $uefi_part for UEFI \t(keep existing data for dual boot with Windows)"
#	lsblk -o NAME,FSTYPE,SIZE,mountpoints "$uefi_part"
 	printf "\n* $root_part for root (/) \t(partition will be formatted)"
#	lsblk -o NAME,FSTYPE,SIZE,mountpoints "$root_part"
	printf "\n* $swap_part for swap \t(partititon will be formatted if not already)\n"
#	lsblk -o NAME,FSTYPE,SIZE,mountpoints "$swap_part"
	printf "\n"
# 	fdisk -l | grep -m 1 -E "(Device)"
#	fdisk -l | grep -E "($uefi_part|$root_part|$swap_part)"
	printf "\t\t\t   Device              Start        End   Sectors   Size Type\n";
	printf "* UEFI partition \t = "; fdisk -l | grep -E "($uefi_part)"
	printf "* Root (/) partition \t = "; fdisk -l | grep -E "($root_part)"
	printf "* Swap partition \t = "; fdisk -l | grep -E "($swap_part)"
	printf "\n"

	read -p "Do you wish to continue? (Y\y to continue, any other input to stop): " response

	if ! [[ "$response" == "y" ]] && ! [[ "$response" == "Y" ]] then
	  printf "\nExiting script.\n"
	  exit 1
	fi

	printf "\n\nWill continue to installing Arch Linux.\n"
	#exit 0;

	printf "Using UK mirrors\n"
 	printf "\nAdding mirrors...\n"

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

	# printf "Creating swap partition - 1GB.\n";
	# parted -s /dev/sda mkpart primary linux-swap 128MiB 1129MiB
	# printf "Formatting swap partition.\n"	
	# mkswap $swap_part
	printf "\nActivating swap partition.\n"
	swapon $swap_part > /dev/null 2>&1;
	 if [[ $? -ne 0 ]]; then
  		printf "Formatting and activating swap file.\n";
    		mkswap $swap_part > /dev/null 2>&1;
      		swapon $swap_part > /dev/null 2>&1;
	else
    		printf "Swap file has been enabled.\n"
	fi

	case $filesystem in
 		ext4)
			printf "\nFormatting root (/) partition as ext4.\n";
			# parted -s /dev/sda mkpart primary ext4 1129MiB 100%
			# printf "Formatting ROOT parition as ext4.\n"
			mkfs.ext4 -F $root_part > /dev/null 2>&1;
   			;;
      		xfs)
			printf "\nFormatting root (/) partition as xfs.\n";
			mkfs.xfs -f $root_part > /dev/null 2>&1;
   			;;
      	esac
	

	printf "\nMounting UEFI, root (/) partitions.\n"
	mount $root_part /mnt
	# mkdir -p /mnt/boot/efi
 	mkdir -p /mnt/boot/EFI
	# mount $uefi_part /mnt/boot/efi
 	mount $uefi_part /mnt/boot/EFI

	printf "\nSetting systemd NTP clock sync.\n"
	timedatectl set-ntp true

	# ─── Bootstrap a writable pacman keyring ───
	rm -rf /etc/pacman.d/gnupg
	mkdir -p /etc/pacman.d/gnupg
	chmod 700 /etc/pacman.d/gnupg
	
	# Initialize the keyring (may stall for entropy)
	pacman-key --init
	
	# Populate with the official Arch keys
	pacman-key --populate archlinux
	
	# Now you can safely update the archlinux-keyring package
	pacman -Sy --noconfirm archlinux-keyring
	# ───────────────────────────────────────────


	printf "\nUpdating Arch package keyring.\n"
	pacman -Sy --noconfirm archlinux-keyring

	printf "\nInstalling base Arch packages.\n"
	pacstrap /mnt linux linux-headers base base-devel linux-firmware intel-ucode bash xfsprogs


	printf "\nCreating fstab with root/swap/UEFI.\n"
	genfstab -U /mnt >> /mnt/etc/fstab
	
	printf "\nChrooting into installation.\n"
	curl -s https://raw.githubusercontent.com/georgeabr/arch/master/arch-2.sh > arch-2.sh; \
 		chmod +x arch-2.sh; cp ./arch-2.sh /mnt; arch-chroot /mnt /bin/bash -c "./arch-2.sh $hostname $username"
	# arch-chroot /mnt

}

if is_positive_number "$1" && is_positive_number "$2" && is_positive_number "$3"; then
	# echo "Success: All three parameters are positive numbers."
	# pass the script parameters to the function
	start_install "$1" "$2" "$3";
else
  show_instructions;
  exit 1;
fi


leave_now()
{
	printf "Will leave now!!\n";
}
