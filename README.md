### Script for installing Arch linux to disk

Bash script to install Arch linux on disk. Flavoured with KDE Plasma 6.  
- UEFI, root and swap partitions required (may be unformatted, except for UEFI, which should already be formatted).  
- UEFI partition should already exist and be formatted, because of interoperability with Windows and other Linux distributions.  
After booting the live Arch ISO, set the `root` password:
```
passwd root
```
Then, install `wget`:
```
pacman -Sy wget
```
Connect to the live session via `ssh` from another computer:
```
ssh root@ip-address
```
Run the below to start the install script:
```bash
wget https://raw.githubusercontent.com/georgeabr/arch/refs/heads/master/arch.sh -O arch.sh; chmod +x arch.sh
```
