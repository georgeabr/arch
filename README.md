### Script for installing Arch linux to disk

Bash script to install Arch linux on disk. Flavoured with KDE Plasma 6.  
It will use only the primary disk (`nvme` or `sda`).
- UEFI, root and swap partitions required (may be unformatted, except for UEFI, which should already be formatted).  
- UEFI partition should already exist and be formatted, because of interoperability with Windows and other Linux distributions.
  
After booting the live Arch ISO, set the `root` password:
```bash
passwd root
```
Then, install `wget`:
```bash
pacman -Sy wget
```
Connect to the live session via `ssh` from another computer:
```bash
ssh root@ip-address
```
Run the below to start the install script:
```bash
wget https://raw.githubusercontent.com/georgeabr/arch/refs/heads/master/arch.sh -O arch.sh; \
  chmod +x arch.sh; ./arch.sh
```
To log installation to a file:
```bash
./arch.sh 2>&1 | tee install-$(date +%Y%m%d_%H%M).log
```
