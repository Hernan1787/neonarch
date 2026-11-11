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
- **Optimisation attempts**: `scripts/tema07-optimize.sh lz4|slim` (drop-in `/etc/mkinitcpio.conf.d/10-neonarch.conf`, plus loader timeout 3 s → 1 s):
  - attempt 1, **lz4**: initramfs compressed with lz4 (faster decompression), `fsck` hook removed (btrfs does not need it);
  - attempt 2, **slim**: back to zstd, without the `fsck` and `kms` hooks (smaller image).
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
Measured on `neonarch-hernan` (VirtualBox, kernel 7.2.15), 2026-11-10/11, **3 boots per variant**, recorded with `scripts/tema07-boot-measure.py` (raw data: `docs/evidence/tema-07/boot-times.csv`; `blame-*.txt`, `critical-chain-*.txt`, `plot-*.svg` per variant).

| Variant | initramfs size | kernel | initrd | kernel + initrd | userspace | **total** |
|---|---|---|---|---|---|---|
| **before** (zstd, default hooks) | 15.2 MB | 0.66 ± 0.02 s | 1.30 ± 0.09 s | **1.96 ± 0.07 s** | 2.56 ± 0.20 s | **4.52 ± 0.25 s** |
| **lz4**, no fsck | 21.9 MB (+44 %) | 0.88 ± 0.01 s | 1.62 ± 0.02 s | **2.50 ± 0.01 s** | 2.46 ± 0.37 s | **4.96 ± 0.38 s** |
| **slim**: zstd, no fsck, no kms | 14.9 MB (−2 %) | 0.73 ± 0.06 s | 1.64 ± 0.23 s | **2.36 ± 0.21 s** | 2.12 ± 0.30 s | **4.48 ± 0.41 s** |

(mean ± standard deviation of 3 boots)

- **Firmware and loader phases are not available on this VM.** `systemd-analyze time` omits them, and systemd-boot's `LoaderTimeInitUSec`/`LoaderTimeExecUSec` EFI variables are absent, so the loader-timeout change (3 s → 1 s, a fixed 2 s less of menu wait by definition) cannot be measured with these tools.
- `systemd-analyze critical-chain` (before): `graphical.target @2.27 s ← multi-user ← getty@tty1 ← systemd-user-sessions ← network.target ← NetworkManager (+222 ms) ← basic.target ← dbus-broker ← sysinit.target ← … ← var-log.mount ← dev-sda2.device`. `blame` is headed by the `.device` units (~1.9 s: udev enumerating the virtual disk and serial ports) and `user@1000.service` (0.9 s, the user manager, outside the critical chain).
- **Discarded:** the first boot recorded (4.44 s) was the first after `pacman -Syu`, so `ldconfig.service` and `systemd-update-done.service` ran in the critical chain. It is kept in `boot-times-discarded.csv`.
- **Rescue demo:** `scripts/tema07-rescue-entries.sh` adds *NeonArch (rescue.target)* and *NeonArch (emergency.target)* to the systemd-boot menu (hold **Space** at power-on).

## 5. Interpretation
- **lz4 made the boot slower, consistently** (+0.55 s in kernel + initrd, with a standard deviation of only 0.01–0.07 s). The idea behind lz4 is that decompression is faster than zstd. But the lz4 image is **44 % bigger** (21.9 vs 15.2 MB), and before decompressing, the kernel image and the initramfs have to be **read** from the virtual disk. On this host (Ryzen 5 3600X) zstd decompresses 15 MB in a few tens of milliseconds, so the extra 6.7 MB of I/O costs more than the decompression it saves. The trade-off "less CPU vs more I/O" only pays off when the CPU is the bottleneck (slow/embedded CPUs), not here.
- **slim did not produce a significant improvement.** Its total (4.48 s) is within the run-to-run variation of "before" (4.52 ± 0.25 s). Removing `fsck` and `kms` saved only 2 % of the image. The initrd phase even varied more (1.37–1.78 s), most likely because the host was not idle (VirtualBox shares the CPU and the SSD with Windows and the browser), which shows how noisy boot measurements in a VM are and why we need several runs.
- **What dominates the boot is not the initramfs** but device discovery (`.device` units ~1.9 s in `blame`) and the virtual disk. A real optimisation would target those: fewer virtual devices (e.g. removing the serial ports and the optical drive from the VM), or real hardware with NVMe.
- **Decision:** we keep the Arch defaults (zstd, default hooks) because they were the fastest of the three we measured. `scripts/tema07-optimize.sh default` restores them. This is the point of measuring: two plausible "optimisations" were **rejected with data** instead of being assumed.
- **Boot flow (for the defence):** UEFI firmware (NVRAM entry *Linux Boot Manager*) → `systemd-bootx64.efi` reads `loader.conf` and `neonarch.conf` → loads `vmlinuz-linux` + `initramfs-linux.img` from the FAT32 ESP and passes `root=UUID=… rootflags=subvol=@ rw` → the kernel unpacks the initramfs and runs its systemd → udev loads `ahci`/`btrfs`, the root is mounted on `/sysroot` → `switch_root` → systemd (PID 1) on the real root reaches `graphical.target` → getty → login → `startx` → i3.
