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
	printf "Will use\n$uefi_boot for UEFI\n$root_drive for root\n$swap_drive for swap\n"
fi


go_ahead()
{
	printf "Will go ahead!\n";
	printf "Creating new GPT table\n";
	parted -s /dev/sda mklabel gpt

	printf "";
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
