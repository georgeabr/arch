### Script for installing Arch linux to disk

Bash script to install Arch linux on disk, mainline kernel. Flavoured with KDE Plasma 6.  
It will use partitions on the disks (`nvme` or `sda`).
- UEFI, root and swap partitions required (may be unformatted, except for UEFI, which should already be formatted).  
- UEFI partition will not be modified for interoperability with Windows and other Linux distributions.
  
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

---
### eficlean

Interactive EFI boot entry management. Queue-based deletion with undo, preview, and confirmation.

### Features

- Queue-based workflow with undo support
- Multi-item selection: single entries, ranges (`1-3`), or lists (`1,3,5`)
- Line number reference instead of boot numbers
- Safety warnings for current boot entry
- Preview and reset commands

### Requirements

- Linux with EFI firmware
- `efibootmgr` installed
- Root access

### Usage

```bash
./eficlean.sh
```

Commands: `[l]ist [d]elete [u]ndo [r]eset [p]review [c]onfirm [q]uit`

### License

SPDX-License-Identifier: NC-SA-BIN-CL-1.2
