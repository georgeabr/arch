
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

# rm *; curl https://raw.githubusercontent.com/georgeabr/arch/master/arch.sh > arch.sh; chmod +x arch.sh

# parted examples
# https://wiki.archlinux.org/index.php/Parted#UEFI/GPT_examples

# will check if any arguments were passed to the program
if [ $# -lt 3 ]
    then
	printf "\nNo arguments supplied. Provide 4 arguments:\n1. UEFI drive\n2. boot drive\n3. root drive\n4. swap drive\n\n" 
exit 0
#    else
#	echo "$#"
fi

uefi_boot="/dev/$1"
boot_drive="/dev/$2"
root_drive="/dev/$3"
swap_drive="/dev/$4"

if [ $# -ge 3 ]
then
	# echo "Script has 4 arguments:\n$1, $2, $3"
	printf "Will use\n$uefi_boot for UEFI\n$boot_drive for boot\n$root_drive for root\n$swap_drive for swap\n"
fi


go_ahead()
{
	printf "\nPart 1 - Initial disk formatting/bootstrap/installation.\n";
	printf "Creating new GPT table\n";
	# parted -s /dev/sda mklabel gpt
	DISK=/dev/sda
	sgdisk --zap-all $DISK

	printf "Creating UEFI partition - 128M.\n"
	# parted -s /dev/sda mkpart primary FAT32 1 128MiB
	# parted -s /dev/sda set 1 esp on
	sgdisk     -n1:0:+101M   -t1:EF00 $DISK

	printf "Formatting UEFI partition.\n"
	mkfs.fat -F32 /dev/sda1

	printf "Creating SWAP partition - 512M.\n";
	# parted -s /dev/sda mkpart primary linux-swap 128MiB 1129MiB
	sgdisk     -n2:0:+512M   -t2:8200 $DISK
	printf "Formatting SWAP partition.\n"	
	mkswap /dev/sda2
	printf "Activating SWAP partition.\n"
	swapon /dev/sda2

	printf "Creating BOOT partition - 512M.\n"
	# parted -s /dev/sda mkpart primary ext4 1129MiB 1641MiB
	sgdisk     -n3:0:+512M   -t3:8300 $DISK
	mkfs.ext4 /dev/sda3

	printf "Creating ROOT ZFS partition - rest of the disk.\n";
	# parted -s /dev/sda mkpart primary ext4 1641MiB 100%
	sgdisk     -n4:0:0   -t4:BF00 $DISK

	partprobe

	printf "Formatting ROOT parition as ZFS.\n"
	# mkfs.ext4 /dev/sda3
	zpool create pool -f -m none /dev/sda4 -o ashift=12
	# printf "zpool create pool -f - success?\n\n"
	zfs set compression=on pool
	zfs set atime=off pool
	zfs create -p pool/ROOT/fedora
	# printf "zfs create -p - success?\n\n"
	zfs set xattr=sa pool/ROOT/fedora
	zpool export pool
	zpool import pool -d /dev/sda4 -o altroot=/mnt
	# zpool import -d /dev/sda4 -R /mnt pool
	zfs set mountpoint=/ pool/ROOT/fedora

	

	printf "Mounting UEFI, BOOT, ROOT partitions.\n"
	# mount /dev/sda3 /mnt
	mkdir -p /mnt/boot
	mount /dev/sda3 /mnt/boot
	mkdir -p /mnt/boot/EFI
	mount /dev/sda1 /mnt/boot/EFI

	printf "Setting systemd NTP clock sync.\n"
	timedatectl set-ntp true

	printf "Updating Arch package keyring.\n"
	pacman -Sy --noconfirm archlinux-keyring

	printf "Installing base Arch packages.\n"
	pacstrap /mnt linux base # base-devel

	printf "Creating fstab with root/swap/UEFI.\n"
	genfstab -U /mnt >> /mnt/etc/fstab

	grep -rl "fsck)" /etc/mkinitcpio.conf | xargs sed -i 's/fsck)/zfs fsck)/g'
	grep -rl "fsck)" /mnt/etc/mkinitcpio.conf | xargs sed -i 's/fsck)/zfs fsck)/g'
	
	exit

	printf "Chrooting into installation.\n"
	curl https://raw.githubusercontent.com/georgeabr/arch/master/VM-zfs-root/arch-2.sh > arch-2.sh; chmod +x arch-2.sh; cp ./arch-2.sh /mnt; arch-chroot /mnt /bin/bash -c "./arch-2.sh"
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
