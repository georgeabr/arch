#!/bin/sh

# git clone https://github.com/georgeabr/arch.git
# git config --global user.email "email@gmail.com"
# git config --global user.name "georgeabr"

# to save passwords
# git config credential.helper store

# commit the code
# git add .; git commit -m "added"; git push -u origin master

# will check if any arguments were passed to the program
if [ $# -lt 3 ]
    then
	echo "No arguments supplied. Provide 3 arguments:\n1. UEFI drive\n2. root drive\n3. swap drive" 
#    else
#	echo "$#"
fi

uefi_boot="/dev/$1"
root_drive="/dev/$2"
swap_drive="/dev/$3"

if [ $# -ge 3 ]
then
	# echo "Script has at least 3 arguments:\n$1, $2, $3"
	echo "Will use\n$uefi_boot for UEFI\n$root_drive for root\n$swap_drive for swap"
fi

# test
