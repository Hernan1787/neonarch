# NeonArch — Manual Installation Log (Layer 1)

> Every member performs this installation **by hand** on their own VM.
> `archinstall` and third-party install scripts are **not** allowed (assignment A.3).
> Each command below is followed by **why** we run it. Each member fills in the
> *Problems found* table at the end with what actually happened on their machine.

| Member | VM software | Disk device | Hostname | Install date |
|---|---|---|---|---|
| Hernán Alonso Gutiérrez Quesada | VirtualBox / QEMU | `/dev/sda` or `/dev/vda` | `neonarch-hernan` | |
| Royner Baltodano Sánchez | | | `neonarch-royner` | |

## Design decisions taken before installing

| Decision | Choice | Why |
|---|---|---|
| Firmware mode | **UEFI** (64-bit) | Required by the assignment (A.2); matches the boot flow of current hardware studied in Topic 7. |
| Partition table | **GPT** | UEFI firmware reads the EFI System Partition (ESP) from a GPT disk. |
| Bootloader | **systemd-boot** | Minimal UEFI boot manager: plain-text entries, no generated config, easy to add a rescue entry and kernel parameters for Topic 7. |
| Root filesystem | **btrfs** with subvolumes | Topic 3 requires a non-ext4 root. btrfs gives copy-on-write snapshots, transparent compression and subvolumes. |
| Init system | **systemd** | Default in Arch; required by Topics 4 and 7 (units, cgroups, targets). |
| Swap | swapfile in its own subvolume + zram (configured later in Topic 2) | A swapfile on btrfs must live in a subvolume with no CoW and no snapshots. |

### Disk layout

| Partition | Size | Type | Filesystem | Mount point |
|---|---|---|---|---|
| `/dev/sda1` | 1 GiB | EFI System (`ef00`) | FAT32 | `/boot` |
| `/dev/sda2` | rest of disk | Linux filesystem (`8300`) | btrfs | `/` (subvolumes below) |

| Subvolume | Mounted at | Why it is separate |
|---|---|---|
| `@` | `/` | The system itself; this is what snapshots capture and what we roll back. |
| `@home` | `/home` | Rolling back the system must not erase user files. |
| `@snapshots` | `/.snapshots` | Snapshots live outside `@` so a rollback does not delete the snapshots themselves. |
| `@var_log` | `/var/log` | Logs must survive a rollback, otherwise we lose the evidence of what broke. |
| `@pkg` | `/var/cache/pacman/pkg` | Package cache is large and reproducible; no point in snapshotting it. |
| `@swap` | `/swap` | A swapfile cannot be in a subvolume that gets snapshotted. |

> In QEMU/virt-manager with virtio disks the device is `/dev/vda` (partitions `vda1`, `vda2`).
> Replace `/dev/sda` accordingly in every command.

---

## 0. Create the VM

- **VirtualBox:** New VM → Type *Linux*, Version *Arch Linux (64-bit)* → 4096 MB RAM, 2 CPUs → 30–40 GB VDI.
  Then **Settings → System → Motherboard → ✅ Enable EFI**. Display → Graphics controller *VMSVGA*, 64 MB video memory.
- **virt-manager:** before finishing, tick *Customize configuration* → Overview → Firmware: **UEFI x86_64 (OVMF_CODE.fd)**, not the `secboot` variant.
- Attach the official ISO from <https://archlinux.org/download/>.
- 📸 **Snapshot `00-empty-vm`.**

**Why:** the assignment requires UEFI, and snapshots let us undo a broken bootloader or partition step in seconds.

## 1. Boot the live ISO and check the environment

```bash
cat /sys/firmware/efi/fw_platform_size
```
**Why:** if it prints `64` we booted in 64-bit UEFI mode. If the file does not exist we are in legacy BIOS mode → turn the VM off and enable EFI.

```bash
loadkeys la-latin1        # optional: only if your physical keyboard is Latin-American
```
**Why:** the console starts with the US layout. We kept the US layout (`KEYMAP=us`), so this step is optional; if a symbol such as `|`, `-` or `'` comes out wrong, load the layout matching the physical keyboard.

```bash
ping -c 3 archlinux.org
timedatectl set-ntp true
timedatectl
```
**Why:** `pacstrap` downloads packages, so we need network (the VM's NAT gives DHCP automatically). The correct time matters because package signatures are checked against certificate validity dates.

## 2. Partition the disk (GPT)

```bash
lsblk
```
**Why:** identify the target disk (≈30–40 GB, no partitions) and make sure we do not wipe the ISO device.

```bash
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI  /dev/sda
sgdisk -n 2:0:0   -t 2:8300 -c 2:ROOT /dev/sda
sgdisk -p /dev/sda
```
**Why:**
- `--zap-all` erases any old GPT/MBR structures so we start clean.
- Partition 1 (1 GiB, type `ef00` = EFI System Partition): the UEFI firmware only knows how to read FAT and looks for bootloaders here. 1 GiB leaves room for several kernels and initramfs images, because systemd-boot loads the kernel from the ESP.
- Partition 2 takes the rest of the disk for btrfs. `-c` sets GPT labels that make the layout readable in `lsblk`.
- `-p` prints the table so we can verify before formatting.

## 3. Format

```bash
mkfs.fat -F 32 -n EFI /dev/sda1
mkfs.btrfs -L ROOT /dev/sda2
```
**Why:** the UEFI spec requires FAT (FAT32) for the ESP. The root uses btrfs (Topic 3). Labels make the partitions identifiable in `lsblk -f` evidence.

## 4. Create btrfs subvolumes

```bash
mount /dev/sda2 /mnt
for sv in @ @home @snapshots @var_log @pkg @swap; do
    btrfs subvolume create /mnt/$sv
done
btrfs subvolume list /mnt
umount /mnt
```
**Why:** subvolumes are independent filesystem trees inside the same btrfs pool. A snapshot of `@` does not include `@home` or `@var_log`, which is exactly what we want for safe rollbacks (see the subvolume table above). We mount the top level once only to create them, then unmount.

## 5. Mount everything in its final place

```bash
OPTS=noatime,compress=zstd:1,space_cache=v2
mount -o $OPTS,subvol=@          /dev/sda2 /mnt
mount --mkdir -o $OPTS,subvol=@home      /dev/sda2 /mnt/home
mount --mkdir -o $OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
mount --mkdir -o $OPTS,subvol=@var_log   /dev/sda2 /mnt/var/log
mount --mkdir -o $OPTS,subvol=@pkg       /dev/sda2 /mnt/var/cache/pacman/pkg
mount --mkdir -o noatime,subvol=@swap    /dev/sda2 /mnt/swap
mount --mkdir -o fmask=0077,dmask=0077   /dev/sda1 /mnt/boot
lsblk -f
```
**Why:**
- `subvol=` selects which subvolume appears at each mount point.
- `noatime` avoids a metadata write on every file *read* (with CoW, each metadata write creates new blocks).
- `compress=zstd:1` compresses data transparently with a fast level: less disk I/O for compressible data, small CPU cost (measured in Topic 3).
- `space_cache=v2` uses the free-space tree, faster on mount than v1.
- The swap subvolume has no compression, because swapfiles cannot be compressed.
- `fmask/dmask=0077` makes the ESP readable only by root; otherwise `bootctl` warns that the random-seed file is world-readable.

## 6. Install the base system

```bash
pacstrap -K /mnt base linux linux-firmware btrfs-progs \
    sudo nano vim networkmanager man-db man-pages git
```
**Why:**
- `base`: minimal userland (glibc, bash, coreutils, systemd, pacman…).
- `linux`: the kernel and its modules; `linux-firmware`: binary firmware some drivers load.
- `btrfs-progs`: userspace tools to manage btrfs (required to check/repair and for snapshots).
- `networkmanager`: network after reboot; the live ISO's networking does **not** carry over.
- `sudo`, editors, `man`, `git` (to clone our repo later).
- `-K` initialises a fresh pacman keyring inside the new system instead of copying the ISO's.

> Running on real hardware? Also add `intel-ucode` or `amd-ucode` (CPU microcode). In a VM the host already applies it.

## 7. Generate fstab

```bash
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```
**Why:** `/etc/fstab` tells systemd what to mount at boot. `-U` uses UUIDs instead of `/dev/sdaX` names, which can change between boots. We check that each subvolume appears with its `subvol=` option.

```bash
sed -i 's/subvolid=[0-9]*,//g' /mnt/etc/fstab
grep -o 'subvol[^ ]*' /mnt/etc/fstab
```
**Why:** `genfstab` writes both `subvolid=256` and `subvol=/@`. A snapshot rollback (Topic 3) replaces `@` with a subvolume that has a **different ID**; if fstab pins the old ID the system mounts the wrong tree or does not boot. Keeping only `subvol=` (the name) makes rollbacks safe.

## 8. Enter the new system

```bash
arch-chroot /mnt
```
**Why:** `chroot` changes the apparent root directory to `/mnt`, so the following commands configure the **installed** system, not the live ISO. `arch-chroot` also mounts `/proc`, `/sys` and `/dev` inside it.

## 9. Time zone and clock

```bash
ln -sf /usr/share/zoneinfo/America/Costa_Rica /etc/localtime
hwclock --systohc
```
**Why:** `/etc/localtime` defines the local time zone. `hwclock --systohc` writes system time to the hardware clock (RTC) and creates `/etc/adjtime`.

## 10. Locale and keyboard

```bash
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/; s/^#es_CR.UTF-8/es_CR.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8'  > /etc/locale.conf
echo 'KEYMAP=us'         > /etc/vconsole.conf
```
**Why:** `locale-gen` compiles the selected locales (language, number and date formats). `LANG` sets the system language (English, as the course deliverables are in English). `KEYMAP` makes the console keyboard layout persistent.

## 11. Hostname

```bash
echo neonarch-hernan > /etc/hostname      # neonarch-royner on Royner's VM
printf '127.0.0.1   localhost\n::1         localhost\n127.0.1.1   neonarch-hernan.localdomain neonarch-hernan\n' > /etc/hosts
```
**Why:** the hostname identifies the machine on the network (and in our evidence logs). `/etc/hosts` resolves it locally without DNS. We overwrite the file (`>`) because the `filesystem` package already ships `localhost` lines; appending would duplicate them.

## 12. Initramfs

```bash
grep ^HOOKS /etc/mkinitcpio.conf
mkinitcpio -P
```
**Why:** the initramfs is a small temporary root filesystem the kernel unpacks into RAM. It contains just enough drivers and tools (block devices, btrfs) to find and mount the real root, then hands control to systemd. Current Arch uses a systemd-based initramfs (`HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`). We record the hooks for Topic 7. `-P` builds images for all presets. We rebuild it here because when `pacstrap` first built it `/etc/vconsole.conf` did not exist yet (warning from `sd-vconsole`). Note: current Arch only builds the `default` image; the `fallback` image is no longer generated by default (`ls /boot` shows only `initramfs-linux.img` and `vmlinuz-linux`).

## 13. Users

```bash
passwd                                       # root password
useradd -m -G wheel -s /bin/bash hernan      # royner on Royner's VM
passwd hernan
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
grep '^%wheel' /etc/sudoers
visudo -c                                    # syntax check: /etc/sudoers: parsed OK
```
**Why:** we do not work as root (least privilege, Topic 9). `-m` creates the home directory. The `wheel` group plus the sudoers rule lets this user run administrative commands with `sudo`, which leaves an audit trail in the journal. `visudo -c` checks the syntax, so a typo cannot lock us out of sudo.

## 14. Bootloader (systemd-boot)

```bash
bootctl install
```
**Why:** copies systemd-boot to the ESP (`/boot/EFI/systemd/` and the removable/fallback path `/boot/EFI/BOOT/BOOTX64.EFI`). Inside `arch-chroot` it prints *"Not booted with EFI or running in a container, skipping EFI variable modifications"*: it cannot write NVRAM variables from a chroot. The firmware still boots through the fallback path `BOOTX64.EFI`; after the first boot we run `sudo bootctl install` again to register the **Linux Boot Manager** NVRAM entry (step 16).

```bash
cat > /boot/loader/loader.conf <<'EOF'
default  neonarch.conf
timeout  3
console-mode max
editor   no
EOF
```
**Why:** `default` selects the entry to boot, and `timeout 3` shows the menu for 3 s. That window is useful for Topic 7, where we press `e` to add parameters. `editor no` blocks editing kernel parameters from the menu, which would allow `init=/bin/sh` root access. We will temporarily enable it (or add a dedicated rescue entry) for the Topic 7 demo.

```bash
ROOT_UUID=$(blkid -s UUID -o value /dev/sda2)
echo $ROOT_UUID
echo 'title   NeonArch'                > /boot/loader/entries/neonarch.conf
echo 'linux   /vmlinuz-linux'         >> /boot/loader/entries/neonarch.conf
echo 'initrd  /initramfs-linux.img'   >> /boot/loader/entries/neonarch.conf
echo "options root=UUID=$ROOT_UUID rootflags=subvol=@ rw" >> /boot/loader/entries/neonarch.conf
cat /boot/loader/loader.conf /boot/loader/entries/neonarch.conf
```
**Why:** each entry tells systemd-boot which kernel and initramfs to load from the ESP and which parameters to pass. `root=UUID=…` identifies the root partition, `rootflags=subvol=@` tells the kernel to mount the `@` subvolume as `/` (not the btrfs top level), and `rw` mounts it read-write. There is no fallback entry because current Arch no longer builds `initramfs-linux-fallback.img` by default. Note the double quotes in the last `echo`: they let the shell substitute `$ROOT_UUID` with the real UUID.

```bash
systemctl enable systemd-boot-update.service
```
**Why:** updates the systemd-boot binary on the ESP automatically when the `systemd` package is upgraded.

## 15. Enable network at boot and leave

```bash
systemctl enable NetworkManager
exit
umount -R /mnt
poweroff
```
**Why:** NetworkManager brings up the network on every boot. `umount -R` flushes all pending writes before shutting down.

Remove the ISO from the VM's optical drive and boot again.
📸 **Snapshot `01-base-installed`.**

## 16. First boot checks and evidence

Log in as your user, then:

```bash
ping -c 3 archlinux.org     # network up (NetworkManager enabled in step 15)?
sudo bootctl install        # now booted in UEFI: registers "Linux Boot Manager" in NVRAM
sudo bootctl status         # Firmware: UEFI · Current Entry: neonarch.conf · Boot Loaders Listed in EFI Variables
```
`bootctl status` **without** sudo prints *Permission denied* for `/boot`: expected, the ESP was mounted with `fmask=0077,dmask=0077` so only root can read it (protection, Topic 9).

```bash
sudo pacman -S --needed git
git clone https://github.com/<team>/neonarch.git ~/neonarch
cd ~/neonarch
./scripts/collect-install-evidence.sh
```
The script stores the outputs required by A.3 (`lsblk -f`, `/etc/fstab`, `bootctl status`, `efibootmgr -v`, `journalctl --list-boots`) under `docs/evidence/install/<hostname>/`. Commit them.

Then run the bootstrap (installs i3, our dotfiles, commands and services):
```bash
./install.sh
```
📸 **Snapshot `02-bootstrap-applied`.**

---

## Problems found and how we solved them

> Fill this in **during** the installation. The assignment explicitly asks for it.

| # | Member | Step | Problem (exact error message) | Cause | Solution |
|---|---|---|---|---|---|
| 1 | Hernán | BIOS | VirtualBox could not run the VM: Task Manager showed *Virtualization: Disabled* | AMD-V (SVM) disabled in the ASUS PRIME B550M-A firmware | Advanced Mode → Advanced → CPU Configuration → **SVM Mode: Enabled** |
| 2 | Hernán | 2 | `zsh: command not found: -n` | Typed the options without the `sgdisk` command name | Re-typed the full command |
| 3 | Hernán | 4 | `btrfs` printed its full help and exited with status 1; `subvolume list` was empty | Typo in the subcommand, no subvolume was created | Re-created each subvolume one by one and verified with `btrfs subvolume list /mnt` |
| 4 | Hernán | 5 | `mount: invalid option -- '0'` | Typed `-0` (zero) instead of `-o` | Corrected the option |
| 5 | Hernán | 6 | `error: target not found: btrds-progs` | Typo in the package name | Re-ran `pacstrap` with `btrfs-progs` |
| 6 | Hernán | 10 | `sed: -e expression #1, char 59: unknown option to 's'`; `locale-gen` generated nothing | Missing space between the sed expression and the file name | Ran one `sed` per locale, verified with `grep -v '^#' /etc/locale.gen` |
| 7 | Hernán | 10 | Shell stuck at a `>` prompt | Opened a quote with `"` and closed with `'`, shell waited for the closing quote | `Ctrl+C`, re-typed with matching quotes |
| 8 | Hernán | 10 | `/etc/vconsole.conf` contained `KETMAP=...` | Typo (would be ignored at boot) | Rewrote it as `KEYMAP=us` |
| 9 | Hernán | 13 | `sed: unterminated 's' command` editing sudoers | Missing `/` delimiter | Corrected and validated with `visudo -c` |
| 10 | Hernán | 14 | `loader.conf` still showed defaults (`#timeout 3`) | Wrote to `/boot/loader.conf` instead of `/boot/loader/loader.conf` | Removed the stray file, wrote to the correct path |
| 11 | Hernán | 14 | Boot entry ended in `rm` instead of `rw` | Typo in the kernel parameter (root would stay read-only) | `sed -i 's/ rm$/ rw/'` and verified with `cat` |
| 12 | Hernán | 16 | i3 showed *"You have an error in your i3 config file!"*, no shortcut worked | Comments at the end of config lines (`set $mod Mod4  # Super`) — i3 only allows comments on their own line | Moved the comments (`sed`), validated with `i3 -C -c ~/.config/i3/config` |
| 13 | Hernán | 16 | `Super+Enter` opened nothing; `pgrep -a alacritty` listed 21 hung processes and RAM grew from 178 MiB to 1.6 GiB; later the whole X display stayed black | Alacritty renders with OpenGL; the VirtualBox VMSVGA adapter has no 3D acceleration and the GL initialisation hung (also with `LIBGL_ALWAYS_SOFTWARE=1`) | Diagnosed from tty2 (`showkey -k` proved the Super key arrived: keycode 125). Replaced the terminal with **xterm** (CPU-rendered via X11) and rebooted |
| 14 | | | | | |

### Known pitfalls (check these first)

| Symptom | Likely cause | Fix |
|---|---|---|
| `/sys/firmware/efi` does not exist | VM booted in BIOS mode | Enable EFI in VM settings, reboot ISO |
| After reboot: *"No bootable medium"* / UEFI shell | NVRAM entry lost (VirtualBox) | Boot the ISO, mount as in step 5, `arch-chroot`, re-run `bootctl install` |
| Kernel panic *"VFS: Unable to mount root fs"* | Wrong UUID or missing `rootflags=subvol=@` | Fix `/boot/loader/entries/arch.conf` from the ISO |
| Drops to *emergency shell* | Bad line in `/etc/fstab` | Check UUIDs and remove `subvolid=` |
| `pacstrap` signature errors | Wrong clock / old ISO keyring | `timedatectl set-ntp true`; `pacman -Sy archlinux-keyring` in the live ISO |
| No network after reboot | NetworkManager not enabled | `sudo systemctl enable --now NetworkManager` |
