# ▲ NeonArch

**A gamer-flavoured custom Linux distribution built on Arch Linux: neon looks, measured internals.**
II Programmed Project · IC-6600 Principles of Operating Systems · TEC, San Carlos campus · II Semester 2026
Alternative A (academic track).

Team: **Hernán Alonso Gutiérrez Quesada** · **Royner Baltodano Sánchez**

<!-- TODO: add screenshots: docs/img/desktop.png (i3 + neon-info) and docs/img/boot.png -->

---

## What is NeonArch?

NeonArch is not a downloadable ISO. It is a **reproducible layer of configuration, scripts,
services and tools** applied on top of an Arch Linux base that each member installed by hand.
Every component exists to demonstrate an operating-systems concept, and each one comes with
**measured evidence** (see `docs/tema-*.md`).

| Layer | Content |
|---|---|
| **1 · Base** | Manual UEFI install on **btrfs** with subvolumes, **systemd-boot**, systemd init, **i3** window manager justified with measurements, idempotent bootstrap `install.sh` |
| **2 · OS topics** | 1 Processes & scheduling · 2 Memory (swap + zram) · 3 btrfs & snapshots · 4 systemd services with cgroup limits · 6 pacman hooks & PKGBUILD · 7 Boot process · 9 Protection & security |
| **3 · Personalisation** | `neon-info` (system report read from `/proc`, `/sys` and syscalls), own commands, mandatory and own keyboard shortcuts, "Neon" cyberpunk colour theme |

## Requirements

- An Arch Linux installation following [`docs/instalacion.md`](docs/instalacion.md):
  UEFI, btrfs root with the subvolume layout `@ @home @snapshots @var_log @pkg @swap`, systemd-boot.
- A normal user in the `wheel` group with `sudo`.
- Network access (packages come from the official Arch repositories; no AUR).
- Suggested VM: 2 vCPU, 4 GB RAM, 30–40 GB disk, **EFI enabled**.

## Installation

```bash
sudo pacman -S --needed git
git clone https://github.com/<team>/neonarch.git ~/neonarch
cd ~/neonarch
./scripts/collect-install-evidence.sh   # Layer 1 evidence of your manual install
./install.sh                            # apply NeonArch
./install.sh                            # run again: must report "0 changes" (idempotent)
reboot                                  # log in on tty1 -> i3 starts automatically
```

`install.sh` runs five stages, each checking the current state before acting:

| Stage | What it does | Idempotency check |
|---|---|---|
| `packages` | installs `pkglist.txt` + VM guest tools | `pacman -T` lists only missing packages |
| `dotfiles` | symlinks `dotfiles/*` into `$HOME` | skips links that already point to the repo; backs up real files |
| `commands` | symlinks `bin/*` into `~/.local/bin` | same as above |
| `system` | copies units, hooks, udev rules and configs into `/etc` | `cmp` against the installed copy |
| `services` | enables units in `config/services.txt` | `systemctl is-enabled` |

Run one stage only: `./install.sh dotfiles`. Every run writes a log to `logs/`.

## Repository map

```
neonarch/
├── README.md
├── install.sh                 # idempotent bootstrap
├── pkglist.txt                # official packages
├── config/                    # services.txt, zram, sysctl, snapper…
├── dotfiles/                  # bash, xinitrc + Xresources (xterm), i3, i3status, rofi, dunst
├── bin/                       # own commands (neon-info, …)
├── systemd/                   # unit files, timers, drop-ins, helper scripts
├── pacman/                    # hooks/ and pkgbuild/
├── security/                  # sudoers, nftables, sshd_config, ACL setup
├── scripts/                   # evidence collection and measurement scripts
├── logs/                      # install.sh execution logs (per member)
└── docs/
    ├── instalacion.md         # manual installation log (why each command)
    ├── de-wm-justification.md # i3 vs XFCE, measured
    ├── responsabilidades.md   # responsibility matrix
    ├── bitacora_ia.md         # AI usage log
    ├── cheatsheet.md          # keyboard shortcuts
    ├── tema-XX-*.md           # one evidence sheet per Layer 2 topic
    └── evidence/              # raw measurements and command outputs
```

## Own commands

| Command | What it does | OS interfaces used | Author |
|---|---|---|---|
| `neon-info` | System report: kernel, uptime, CPU, GPU/NPU + driver, memory/swap/zram, processes, scheduler, root FS. `--sources` shows the interface behind each value; `--json` for scripts. | `/proc/{meminfo,swaps,uptime,loadavg,cpuinfo,[pid]/stat,self/mounts}`, `/sys/{bus/pci,block/zram*,devices/system/cpu,class/accel,firmware/efi}`, `uname(2)`, `statvfs(2)`, `sched_getscheduler(2)`, `sched_getaffinity(2)` | Royner Baltodano Sánchez |

## Project status

| Item | Status |
|---|---|
| H1 — manual install (both members), DE/WM, repo, matrix | 🟡 in progress |
| H2 — 4 topics with evidence, bootstrap working | ⬜ |
| H3 — 7 topics, Layer 3, reproducibility, report, defence | ⬜ |

## Sources and credits
- [Arch Wiki — Installation guide](https://wiki.archlinux.org/title/Installation_guide), [btrfs](https://wiki.archlinux.org/title/Btrfs), [systemd-boot](https://wiki.archlinux.org/title/Systemd-boot), [i3](https://wiki.archlinux.org/title/I3)
- Silberschatz, Galvin, Gagne — *Operating System Concepts*, 10th ed.
- AI usage is declared in [`docs/bitacora_ia.md`](docs/bitacora_ia.md).
