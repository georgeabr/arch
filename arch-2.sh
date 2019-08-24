#!/bin/bash
	printf "Configuring locale to LONDON/UK.\n"
	rm -rf /etc/localtime
	ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
	hwclock --systohc --utc
	grep -rl "#en_GB.UTF-8 UTF-8" /etc/locale.gen | xargs sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g'
	echo LANG=en_GB.UTF-8 > /etc/locale.conf
	export LANG=en_GB.UTF-8
