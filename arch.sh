#!/bin/bash

# Bump this number whenever you push a change to GitHub, so the self-update
# check below can tell an older local copy from a newer (or unpushed) one.
SCRIPT_VERSION=1

# --- root check ---
if [[ $EUID -ne 0 ]]; then
   printf "\n\e[1;31mError: This script must be run as root (use sudo).\e[0m\n\n"
   exit 1
fi

# --- self-update check ---
# Compares SCRIPT_VERSION against the version on GitHub; only updates if the
# remote version is strictly higher, so an unpushed local copy that's ahead
# of GitHub is never overwritten by an older remote one.
# Set ARCH_SH_SKIP_UPDATE=1 to skip this (also set automatically after an update,
# to prevent a re-download loop).
if [[ -z "$ARCH_SH_SKIP_UPDATE" ]] && ! command -v curl &>/dev/null; then
    printf "\ncurl not found - skipping self-update check.\n"
fi

if [[ -z "$ARCH_SH_SKIP_UPDATE" ]] && command -v curl &>/dev/null; then
    script_url="https://raw.githubusercontent.com/georgeabr/arch/master/arch.sh?_=$(date +%s)"
    script_path="$(readlink -f "$0")"
    tmp_script=$(mktemp)

    printf "\nChecking for a newer version of this script...\n"
    if curl -fsS --max-time 5 -o "$tmp_script" "$script_url"; then
        remote_version="$(grep -m1 '^SCRIPT_VERSION=' "$tmp_script" | cut -d= -f2)"
        remote_version="${remote_version:-0}"

        if ! [[ "$remote_version" =~ ^[0-9]+$ ]]; then
            printf "Could not determine the version of the script on GitHub - skipping update to be safe.\n"
        elif (( remote_version > SCRIPT_VERSION )); then
            if cp "$tmp_script" "$script_path"; then
                printf "A newer version is available (local: %s, GitHub: %s) - updating and restarting...\n\n" "$SCRIPT_VERSION" "$remote_version"
                chmod +x "$script_path"
                rm -f "$tmp_script"
                export ARCH_SH_SKIP_UPDATE=1
                exec "$script_path" "$@"
            else
                printf "A newer version is available, but the update failed (couldn't write to %s) - continuing with current version.\n" "$script_path"
            fi
        elif (( remote_version < SCRIPT_VERSION )); then
            printf "Local version (%s) is newer than the version on GitHub (%s) - skipping update. Don't forget to push your changes.\n" "$SCRIPT_VERSION" "$remote_version"
        else
            printf "Script is already up to date (version %s).\n" "$SCRIPT_VERSION"
        fi
    else
        printf "Could not check for updates (no internet or GitHub unreachable) - continuing with current version.\n"
    fi
    rm -f "$tmp_script" 2>/dev/null
fi

# --- start self-logging ---
timestamp=$(date +%Y%m%d_%H%M)
logfile="install-${timestamp}.log"
# redirect all output (stdout+stderr) into tee => logfile _and_ console
exec > >(tee -a "$logfile") 2>&1

# echo "==> Logging install run to $logfile"
# ----------------------------------------

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
# ./arch.sh 2>&1 | tee install-$(date +%Y%m%d_%H%MM).log

# CONNECT VIA SSH FROM ANOTHER COMPUTER
# - set password for root user
# passwd
# - run the ssh command:
# ssh root@ip-address

# parted examples
# https://wiki.archlinux.org/index.php/Parted#UEFI/GPT_examples

# hostname="arx"
hostname="arx-$(tr -dc 'a-z' </dev/urandom | head -c3)"
username="george"
# can be ext4 or xfs
filesystem="ext4"

# New: Function to check if a value is in "X-Y" format (e.g., 1-1, 2-3)
is_disk_partition_format() {
  [[ "$1" =~ ^[0-9]+-[0-9]+$ ]]
}

show_instructions() {
printf "\n\e[1mArch Linux Installer (Intel/KDE Plasma 6)\e[0m\n"
    printf "Hostname: \e[1m$hostname\e[0m | User: \e[1m$username\e[0m | Filesystem: \e[1m$filesystem\e[0m\n"
    printf "Usage: \e[1m$0 UEFI-PART ROOT-PART SWAP-PART\e[0m (e.g., $0 1-1 1-3 1-2)\n\n"
    
    printf "1. Use \e[1mcfdisk\e[0m to partition your primary disk before running this.\n"
    printf "2. UEFI partition should already exist; \e[1mRoot will be formatted\e[0m.\n"
    printf "3. Identifiers below use 'DISK-PART' format based on /dev/nvme0n1 or /dev/sda.\n\n"
    
    printf "Available partitions:\n"
	
	# Create a temporary awk script for display
    local awk_script_display=$(mktemp)
    cat << 'EOF' > "$awk_script_display"
BEGIN {
    current_disk_line = ""; current_disk_buffer = ""; has_partitions = 0; disk_counter = 0; partition_on_disk_count = 0;
    # Updated exclude_regex to be more general for partition headers, accounting for potential leading spaces and variations
    exclude_regex = "^\\s*(Units: sectors of|Sector size \\(|I/O size \\(|Device\\s+(Boot\\s+)?Start\\s+End\\s+Sectors\\s+Size\\s+(Id\\s+)?Type)$";
}
$0 ~ exclude_regex { next }
/^Disk \/dev\// {
    if (has_partitions) { if (current_disk_buffer != "") { print current_disk_buffer; } } else { current_disk_buffer = ""; }
    current_disk_line = $0; current_disk_buffer = ""; has_partitions = 0; next;
}
/^\/dev\// && !/Disklabel/ {
    if (!has_partitions) {
        disk_counter++; partition_on_disk_count = 0;
        print current_disk_line;
        if (current_disk_buffer != "") { print current_disk_buffer; }
        # Removed leading newline from printf to remove blank line
        printf "  %-28s %-10s %-10s %-10s %-8s %s\n", "Device", "Start", "End", "Sectors", "Size", "Type";
        has_partitions = 1; current_disk_buffer = "";
    }
    partition_on_disk_count++;
    
    device = $1;
    local_start = ""; local_end = ""; local_sectors = ""; local_size = "";
    
    # Dynamically find the 'Size' field (e.g., 402M, 23.3G)
    size_field_idx = 0;
    for (k = 1; k <= NF; k++) {
        if ($k ~ /^[0-9.]+(M|G|T|K|B)$/) { # Match fields like 402M, 23.3G, 18.4G
            size_field_idx = k;
            local_size = $k;
            break;
        }
    }

    # Deduce Start, End, Sectors based on size_field_idx relative to Device ($1)
    # This assumes consistent relative positioning before Size
    if (size_field_idx > 5) { # Likely DOS with Boot flag, or more complex output
        local_start = $(size_field_idx - 3);
        local_end = $(size_field_idx - 2);
        local_sectors = $(size_field_idx - 1);
        type_start_field = size_field_idx + 2; # Type after Id
    } else { # Likely GPT or DOS without Boot flag
        local_start = $2;
        local_end = $3;
        local_sectors = $4;
        type_start_field = size_field_idx + 1; # Type after Size (or Id if present)
        # Refine type_start_field if there's an 'Id' field after Size
        if ($(size_field_idx + 1) ~ /^[0-9a-fA-F]+$/) { # Check if next field is an ID (hex/numeric)
            type_start_field = size_field_idx + 2;
        }
    }

    local_type = "";
    for (j = type_start_field; j <= NF; j++) {
        local_type = local_type $j (j < NF ? " " : "");
    }
    sub(/^ /, "", local_type); # Remove leading space if any

    printf "  %-28s %-10s %-10s %-10s %-8s %s\n", (disk_counter "-" partition_on_disk_count ". " device), local_start, local_end, local_sectors, local_size, local_type;
    next;
}
{ # Rule for accumulating other relevant lines (like Disklabel, etc.)
    if (current_disk_line != "") {
        if (current_disk_buffer != "") { current_disk_buffer = current_disk_buffer "\n" $0; } else { current_disk_buffer = $0; }
    }
}
END { # Handle the very last disk's output
    if (has_partitions) { if (current_disk_buffer != "") { print current_disk_buffer; } }
}
EOF
    # Use the temporary awk script
    fdisk -l | awk -f "$awk_script_display"
    rm "$awk_script_display" # Clean up the temporary file
}


start_install() {
# --- Internet check ---
    printf "\nChecking for internet connectivity...\n"
    if ! ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
        printf "\n\e[1;31mError: No internet connection detected.\e[0m\n"
        printf "Please connect to the network using \`nmtui\` before running this script.\n\n"
		# CLOSE the logging pipe so the terminal returns to prompt immediately 
        exec >&- 2>&-
		
		# This kills the script process immediately and returns to prompt
        { sleep 0.1; kill -9 -$$; } &
        exit 1
    fi
    printf "Internet connection verified.\n"
    # -----------------------
	
	local uefi_param="$1"
	local root_param="$2"
	local swap_param="$3"

    # New: Parse fdisk -l to create a map of "disk_num-part_num" to actual device path
    declare -A all_partitions_map # Associative array for "disk_num-part_num" => "/dev/device"

    # Create a temporary awk script for parsing fdisk output
    local awk_script_parse=$(mktemp)
    cat << 'EOF' > "$awk_script_parse"
BEGIN {
    current_disk_device_awk = "";
    current_disk_num_awk = 0;
    partition_num_on_disk_awk = 0;
    # Updated exclude_regex_parse to be more general for partition headers
    exclude_regex_parse = "^\\s*(Units: sectors of|Sector size \\(|I/O size \\(|Device\\s+.*Type)$";
}
$0 ~ exclude_regex_parse { next }
/^Disk \/dev\// {
    partition_num_on_disk_awk = 0;
    current_disk_device_awk = $2; sub(/:$/, "", current_disk_device_awk);
    next;
}
/^\/dev\// && !/Disklabel/ {
    if (current_disk_device_awk != "" && substr($1, 1, length(current_disk_device_awk)) == current_disk_device_awk) {
        if (partition_num_on_disk_awk == 0) {
            current_disk_num_awk++;
        }
        partition_num_on_disk_awk++;
        print current_disk_num_awk "-" partition_num_on_disk_awk " " $1;
    }
    next;
}
EOF
    # Capture raw fdisk output and process with the temporary awk script to build the map
    local fdisk_output_raw=$(fdisk -l)
    readarray -t fdisk_processed_lines < <(echo "$fdisk_output_raw" | awk -f "$awk_script_parse")
    rm "$awk_script_parse" # Clean up the temporary file
    
    # Populate the associative array in bash
    for line in "${fdisk_processed_lines[@]}"; do
        key=$(echo "$line" | awk '{print $1}')
        value=$(echo "$line" | awk '{print $2}')
        all_partitions_map["$key"]="$value"
    done

    # Lookup partitions using the provided parameters (e.g., 2-1, 2-3, 2-2)
	uefi_part="${all_partitions_map["$uefi_param"]}"
	root_part="${all_partitions_map["$root_param"]}"
	swap_part="${all_partitions_map["$swap_param"]}"

    # Validate if the lookups were successful
    if [[ -z "$uefi_part" || -z "$root_part" || -z "$swap_part" ]]; then
        printf "\n\e[1;31mError: One or more partition identifiers were invalid or not found.\e[0m\n"
        printf "Please ensure the identifiers (e.g., '1-1') match available partitions.\n"
        show_instructions; # Show instructions again with valid partitions
        exit 1;
    fi

# --- Duplicate partition check ---
    if [[ "$uefi_part" == "$root_part" || "$uefi_part" == "$swap_part" || "$root_part" == "$swap_part" ]]; then
        printf "\n\e[1;31mError: You cannot use the same partition for multiple roles.\e[0m\n"
        printf "Your input: UEFI: $uefi_param | Root: $root_param | Swap: $swap_param\n"
        exit 1
    fi

    # Check UEFI format
    if [[ $(lsblk -no FSTYPE "$uefi_part") != "vfat" ]]; then
        printf "\n\e[1;31mError: UEFI partition is not FAT32.\e[0m\n"
        exec >&- 2>&-
        { sleep 0.1; kill -9 -$$; } &
        exit 1
    fi

	printf "\nThe Arch install script will use the settings:\n";
 	printf "%s\n" "* host name  = $hostname";
 	printf "%s\n" "* user name  = $username";
	printf "%s\n" "* filesystem = $filesystem";

 
	printf "\nThe Arch install script will use the below partitions:\
	\n* $uefi_part for UEFI \t(keep existing data for dual boot with Windows)"
 	printf "\n* $root_part for root (/) \t(partition will be formatted)"
	printf "\n* $swap_part for swap \t(partition will be formatted if not already)\n"
	printf "\n"

    # Simplified display for chosen partitions within start_install
    printf "\t\t\t   Device\t\tSize\t\tType\n"

    local parts_to_display=("$uefi_part" "$root_part" "$swap_part")
    local labels=("* UEFI partition" "* Root (/) partition" "* Swap partition")

    # Create a temporary awk script for displaying selected partitions
    local awk_script_selected_display=$(mktemp)
    cat << 'EOF' > "$awk_script_selected_display"
# No BEGIN block needed here for -v variables
/^\/dev\// {
    # p_dev_awk_var is directly available from the -v flag
    if ($1 == p_dev_awk_var) {
        local_size = "";
        local_type = "";
        
        # Dynamically find the 'Size' field (e.g., 402M, 23.3G)
        size_field_idx = 0;
        for (k = 1; k <= NF; k++) {
            if ($k ~ /^[0-9.]+(M|G|T|K|B)$/) { # Match fields like 402M, 23.3G, 18.4G
                size_field_idx = k;
                local_size = $k;
                break;
            }
        }

        # Deduce where 'Type' starts based on size_field_idx
        type_start_field = size_field_idx + 1; # Default: Type starts right after Size

        # If the field *after* Size is an ID (hex/numeric), then Type starts two fields after Size
        if ($(size_field_idx + 1) ~ /^[0-9a-fA-F]+$/ || $(size_field_idx + 1) ~ /^[0-9]+$/) {
            type_start_field = size_field_idx + 2;
        }
        
        for (j=type_start_field; j<=NF; ++j) local_type = local_type $j (j<NF ? " " : "");
        sub(/^ /, "", local_type); # Remove leading space from type
        printf "%-20s\t%-8s\t%s\n", $1, local_size, local_type;
        exit;
    }
}
EOF

    for i in "${!parts_to_display[@]}"; do
        local part_dev="${parts_to_display[$i]}"
        local label="${labels[$i]}"
        printf "%s \t = " "$label"
        # Pass p_dev as an argument to awk using the -v flag
        fdisk -l | awk -v p_dev_awk_var="$part_dev" -f "$awk_script_selected_display"
    done
    rm "$awk_script_selected_display" # Clean up the temporary file
	printf "\n"

	read -p "Do you wish to continue? (Y\y to continue, any other input to stop): " response

	if ! [[ "$response" == "y" ]] && ! [[ "$response" == "Y" ]]; then
	  printf "\nExiting script.\n"
	  exit 1
	fi

	printf "\n\nWill continue to installing Arch Linux.\n"
	printf "Using UK mirrors\n"
 	printf "\nAdding mirrors...\n"

	curl -s "https://archlinux.org/mirrorlist/?country=GB&protocol=http&protocol=https&use_mirror_status=on" \
	  | sed -E 's/^#(Server.*)/\1/' \
	  > /etc/pacman.d/mirrorlist
	
	printf "\nPart 1 - Initial Arch bootstrap/installation.\n";
	printf "\nActivating swap partition.\n"
	swapon $swap_part > /dev/null 2>&1;
    if [[ $? -ne 0 ]]; then
  		printf "Formatting and activating swap file.\n";
    		mkswap $swap_part > /dev/null 2>&1;
            swapon $swap_part > /dev/null 2>&1;
            if [[ $? -ne 0 ]]; then
                printf "\n\e[1;31mError: Failed to activate swap partition $swap_part.\e[0m\n"
                exit 1
            fi
	fi
    printf "Swap file has been enabled.\n"

	case $filesystem in
 		ext4)
			printf "\nFormatting root (/) partition as ext4.\n";
			mkfs.ext4 -F $root_part > /dev/null 2>&1;
 		;;
      		xfs)
			printf "\nFormatting root (/) partition as xfs.\n";
			mkfs.xfs -f $root_part > /dev/null 2>&1;
   		;;
 	esac
    if [[ $? -ne 0 ]]; then
        printf "\n\e[1;31mError: Failed to format root partition $root_part.\e[0m\n"
        exit 1
    fi
	
	printf "\nMounting UEFI, root (/) partitions.\n"
	mount $root_part /mnt
    if [[ $? -ne 0 ]]; then
        printf "\n\e[1;31mError: Failed to mount root partition $root_part on /mnt.\e[0m\n"
        exit 1
    fi
 	mkdir -p /mnt/boot/EFI
 	mount $uefi_part /mnt/boot/EFI
    if [[ $? -ne 0 ]]; then
        printf "\n\e[1;31mError: Failed to mount UEFI partition $uefi_part on /mnt/boot/EFI.\e[0m\n"
        exit 1
    fi

	printf "\nSetting systemd NTP clock sync.\n"
	timedatectl set-ntp true

	printf "\nInstalling base Arch packages.\n"
	pacstrap /mnt linux linux-headers base base-devel linux-firmware intel-ucode bash xfsprogs
    if [[ $? -ne 0 ]]; then
        printf "\n\e[1;31mError: pacstrap failed to install the base system.\e[0m\n"
        exit 1
    fi


	printf "\nCreating fstab with root/swap/UEFI.\n"
	genfstab -U /mnt >> /mnt/etc/fstab
    if [[ $? -ne 0 ]]; then
        printf "\n\e[1;31mError: genfstab failed to generate /etc/fstab.\e[0m\n"
        exit 1
    fi
	
	printf "\nChrooting into installation.\n"
    
    # This disables account locking by setting deny to 0 in faillock.conf
    arch-chroot /mnt /bin/bash -c "sed -i 's/^#\?deny =.*/deny = 0/' /etc/security/faillock.conf"
    if [[ $? -ne 0 ]]; then
        printf "\n\e[1;31mError: Failed to chroot into /mnt to update faillock.conf.\e[0m\n"
        exit 1
    fi

	curl -s https://raw.githubusercontent.com/georgeabr/arch/master/arch-2.sh > arch-2.sh; \
 		chmod +x arch-2.sh; cp ./arch-2.sh /mnt; arch-chroot /mnt /bin/bash -c "./arch-2.sh $hostname $username";
    if [[ $? -ne 0 ]]; then
        printf "\n\e[1;31mError: arch-2.sh failed inside the chroot.\e[0m\n"
        exit 1
    fi
   	# Delete after chroot exits
    	rm -f /mnt/arch-2.sh
	echo "Unmounting all filesystems under /mnt..."
	umount -R /mnt
}

# This is the entry point for the script, validating parameters
if is_disk_partition_format "$1" && is_disk_partition_format "$2" && is_disk_partition_format "$3";
then
	start_install "$1" "$2" "$3";
else
  printf "\n\e[1;31mError: Missing or invalid arguments.\e[0m\n"
  arg_labels=("UEFI-PART" "ROOT-PART" "SWAP-PART")
  for i in 1 2 3; do
    arg_val="${!i}"
    if [[ -z "$arg_val" ]]; then
      printf "  - %-10s not provided\n" "${arg_labels[$((i-1))]}"
    elif ! is_disk_partition_format "$arg_val"; then
      printf "  - %-10s '%s' is not in DISK-PART format (e.g. '1-1')\n" "${arg_labels[$((i-1))]}" "$arg_val"
    fi
  done
  printf "\n"
  show_instructions;
  exit 1;
fi
