### Script for installing Arch linux to disk

Bash script to install Arch linux on disk, mainline kernel. Flavoured with KDE Plasma 6.  
It will use partitions on the disks (`nvme` or `sda`).
- UEFI, root and swap partitions required (may be unformatted, except for UEFI, which should already be formatted).  
- UEFI partition should already exist and be formatted, for interoperability with Windows and other Linux distributions.
  
After booting the live Arch ISO, set the `root` password:
```bash
passwd root
```
Connect to the live session via `ssh` from another computer:
```bash
ssh root@ip-address
```
Run the below to start the install script:
```bash
curl -L -o arch.sh https://raw.githubusercontent.com/georgeabr/arch/refs/heads/master/arch.sh; \
  chmod +x arch.sh
```
Installation is autmatically logged to a file `install-$(date +%Y%m%d_%H%M).log`.  
