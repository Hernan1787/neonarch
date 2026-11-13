# Responsibility Matrix (Annex 1)

Team: **Hernán Alonso Gutiérrez Quesada** · **Royner Baltodano Sánchez**
Alternative A — NeonArch, a custom Linux distribution on Arch.

The **owner** must be able to explain, modify live and defend the component without help.
The Git history must show each owner's commits on their components across the three weeks.

## Layer 1 — Base installation and reproducibility

| Component | Owner | Support | Repository path | Evidence |
|---|---|---|---|---|
| Manual installation (own VM) | Each member | — | `docs/instalacion.md` | `docs/evidence/install/<host>/` |
| DE/WM choice and justification | Hernán Alonso Gutiérrez Quesada | — | `dotfiles/`, `scripts/measure-desktop.sh` | `docs/de-wm-justification.md` |
| Bootstrap `install.sh` + `pkglist.txt` | Hernán Alonso Gutiérrez Quesada | — | `install.sh`, `pkglist.txt`, `config/` | `logs/install-*.log` (one per member) |

## Layer 2 — OS topics (7 of 9)

| Topic / module | Owner | Support | Repository path | Evidence sheet |
|---|---|---|---|---|
| Topic 1 · Processes and scheduling | Hernán Alonso Gutiérrez Quesada | — | `bin/` (process tool), `scripts/tema01-*` | `docs/tema-01-procesos.md` |
| Topic 2 · Memory | Royner Baltodano Sánchez | Hernán Alonso Gutiérrez Quesada | `config/zram-generator.conf`, `scripts/measure-swap-zram.sh` | `docs/tema-02-memoria.md` (+ `docs/tema2-swap-zram.md`) |
| Topic 3 · Filesystem (btrfs) | Hernán Alonso Gutiérrez Quesada | — | `scripts/tema03-*`, `scripts/fio-summary.py` | `docs/tema-03-sistema-archivos.md` |
| Topic 4 · Service management | Hernán Alonso Gutiérrez Quesada | — | `systemd/`, `scripts/tema04-measure.sh` | `docs/tema-04-servicios.md` |
| Topic 6 · Package management | Hernán Alonso Gutiérrez Quesada | — | `pacman/hooks/`, `pacman/pkgbuild/` | `docs/tema-06-pacman.md` |
| Topic 7 · Boot process | Hernán Alonso Gutiérrez Quesada | — | `scripts/tema07-*`, loader entries | `docs/tema-07-arranque.md` |
| Topic 9 · Protection and security | Royner Baltodano Sánchez | Hernán Alonso Gutiérrez Quesada | nftables, sudoers, ACL, SSH on `neonarch-roy` | `docs/tema-09-seguridad.md` (+ `docs/tema9-seguridad.md`) |

**Topics not implemented:** 5 (Concurrency and IPC) and 8 (I/O and devices).
Reason: inside a VM, Topic 8's GPU/NPU and hot-plug evidence would be limited to virtual
devices; with a two-week effective window we prioritised topics whose evidence can be
fully measured on our VMs. The GPU/NPU driver identification required by the Unit 1
connection is still covered by `neon-info` (Layer 3), which reports `vmwgfx` for the VM's
VMware SVGA II adapter.

**Note on the workload split:** Hernán owns five topics and Royner the minimum required by
the assignment (two). Each owner implemented, measured and documented their own topics and
can defend them individually.

## Layer 3 — Commands and shortcuts

| Component | Owner | Support | Repository path |
|---|---|---|---|
| Mandatory command `neon-info` | Hernán Alonso Gutiérrez Quesada | — | `bin/neon-info` |
| Free commands `neon-ps`, `neon-boost`, `neon-net` | Hernán Alonso Gutiérrez Quesada | — | `bin/` |
| Free commands `neonarch-health`, `neonarch-clean`, `neonarch-calc` | Royner Baltodano Sánchez | — | `bin/`, `docs/tema-commands.md` |
| Support command `neon-mem` (Topic 2 monitor) | Hernán Alonso Gutiérrez Quesada | — | `bin/neon-mem` |
| Package `neonarch-tools` (all commands) | Hernán Alonso Gutiérrez Quesada | — | `pacman/pkgbuild/neonarch-tools/` |
| Mandatory shortcuts | Hernán Alonso Gutiérrez Quesada | — | `dotfiles/i3/config` |
| Free shortcuts (3 each) | Each member | — | `dotfiles/i3/config`, `docs/cheatsheet.md` |
