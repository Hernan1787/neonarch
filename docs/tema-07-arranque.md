# Topic 7: Boot process
**Owner:** Hernán Alonso Gutiérrez Quesada

## 1. What was implemented
**Boot chain of NeonArch** (configured by hand in `docs/instalacion.md`, steps 12–14):

| # | Stage | What happens | Our configuration |
|---|---|---|---|
| 1 | **UEFI firmware** (VirtualBox OVMF) | POST, reads the NVRAM boot entries, loads an EFI executable from the ESP (FAT32) | entry *Linux Boot Manager* → `\EFI\systemd\systemd-bootx64.efi` (fallback `\EFI\BOOT\BOOTX64.EFI`) |
| 2 | **systemd-boot** | shows the menu, reads `loader.conf` and `entries/*.conf`, loads kernel + initramfs from the ESP, passes the command line | `/boot/loader/loader.conf`, `entries/neonarch.conf`, `neonarch-rescue.conf`, `neonarch-emergency.conf` |
| 3 | **Linux kernel** | decompresses itself, initialises memory, CPUs and drivers, unpacks the initramfs into a tmpfs and runs its `/init` | `root=UUID=… rootflags=subvol=@ rw` |
| 4 | **initramfs** (mkinitcpio, systemd-based) | loads the modules needed for the root device (block, btrfs), finds the root by UUID, mounts `@` on `/sysroot`, `switch_root` | `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)` |
| 5 | **systemd (PID 1)** | builds the dependency graph of units, mounts `/etc/fstab`, starts services in parallel up to `default.target` | `NetworkManager`, `neon-health`, snapper timers… |
| 6 | **getty → login → startx → i3** | `getty@tty1` asks for the login; `~/.bash_profile` runs `startx` on tty1 | `dotfiles/bash/bash_profile`, `dotfiles/x11/xinitrc` |

- **Measurement** of every boot: `scripts/tema07-boot-measure.py`.
- **Optimisation**: `scripts/tema07-optimize.sh`: loader timeout 3 s → 1 s, and initramfs compression zstd → **lz4** (drop-in `/etc/mkinitcpio.conf.d/10-neonarch.conf`).
- **Rescue entries**: `scripts/tema07-rescue-entries.sh` adds systemd-boot entries with `systemd.unit=rescue.target` and `systemd.unit=emergency.target` for the live demo.

## 2. Operating-systems concept
System boot: firmware, bootstrap loader, kernel initialisation, init process, run levels/targets.
Silberschatz et al., *Operating System Concepts* 10th ed., §2.9 (Building and Booting an Operating System); `bootup(7)`, `systemd.special(7)`, `systemd-analyze(1)`, `mkinitcpio(8)`.

## 3. Measurement method
1. **Before:** reboot the VM 3 times. After each boot (once the desktop is up), run `./scripts/tema07-boot-measure.py before`. It records `systemd-analyze time` (firmware, loader, kernel, initrd, userspace, total) for that boot ID, and for the first boot also `blame`, `critical-chain` and `plot` (SVG timeline).
2. **Optimise:** `./scripts/tema07-optimize.sh` (also saves the initramfs size before/after).
3. **After:** reboot 3 times, running `./scripts/tema07-boot-measure.py after` after each boot.
4. Table: `docs/evidence/tema-07/summary.md`; raw: `boot-times.csv`.

**Rescue demo (live):** `./scripts/tema07-rescue-entries.sh`, reboot holding **Space** → choose *NeonArch (rescue.target)* → root password → `systemctl list-units --type=target` shows only the rescue target; `systemctl default` continues the normal boot.

## 4. Results
<!-- paste docs/evidence/tema-07/summary.md; add the first lines of blame-before.txt -->

## 5. Interpretation
<!-- loader phase ≈ menu timeout; lz4 trades a slightly bigger initramfs for faster decompression;
discuss which services dominate userspace (blame / critical-chain) and why the firmware phase
cannot be changed from the OS. -->
