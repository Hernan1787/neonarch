# Responsibility Matrix (Annex 1)

Team: **Hernán Alonso Gutiérrez Quesada** · **Royner Baltodano Sánchez**
Alternative A — NeonArch, a custom Linux distribution on Arch.

The **owner** must be able to explain, modify live and defend the component without help.
The Git history must show each owner's commits on their components across the three weeks.

## Layer 1 — Base installation and reproducibility

| Component | Owner | Support | Repository path | Evidence |
|---|---|---|---|---|
| Manual installation (own VM) | Each member | — | `docs/instalacion.md` | `docs/evidence/install/<host>/` |
| DE/WM choice and justification | Royner Baltodano Sánchez | Hernán Alonso Gutiérrez Quesada | `dotfiles/`, `scripts/measure-desktop.sh` | `docs/de-wm-justification.md` |
| Bootstrap `install.sh` + `pkglist.txt` | Hernán Alonso Gutiérrez Quesada | Royner Baltodano Sánchez | `install.sh`, `pkglist.txt`, `config/` | `logs/install-*.log` |

## Layer 2 — OS topics (7 of 9)

| Topic / module | Owner | Support | Repository path | Evidence sheet |
|---|---|---|---|---|
| Topic 1 · Processes and scheduling | Royner Baltodano Sánchez | Hernán Alonso Gutiérrez Quesada | `bin/` (process tool) | `docs/tema-01-procesos.md` |
| Topic 2 · Memory | Royner Baltodano Sánchez | Hernán Alonso Gutiérrez Quesada | `config/zram-generator.conf`, `bin/` (memory monitor) | `docs/tema-02-memoria.md` |
| Topic 3 · Filesystem (btrfs) | Hernán Alonso Gutiérrez Quesada | Royner Baltodano Sánchez | `config/snapper/`, `scripts/` | `docs/tema-03-sistema-archivos.md` |
| Topic 4 · Service management | Hernán Alonso Gutiérrez Quesada | Royner Baltodano Sánchez | `systemd/` | `docs/tema-04-servicios.md` |
| Topic 6 · Package management | Hernán Alonso Gutiérrez Quesada | Royner Baltodano Sánchez | `pacman/hooks/`, `pacman/pkgbuild/` | `docs/tema-06-pacman.md` |
| Topic 7 · Boot process | Hernán Alonso Gutiérrez Quesada | Royner Baltodano Sánchez | `docs/`, loader entries | `docs/tema-07-arranque.md` |
| Topic 9 · Protection and security | Royner Baltodano Sánchez | Hernán Alonso Gutiérrez Quesada | `security/` | `docs/tema-09-seguridad.md` |

**Topics not implemented:** 5 (Concurrency and IPC) and 8 (I/O and devices).
Reason: inside a VM, topic 8's GPU/NPU and hot-plug evidence would be limited to virtual
devices. With two members and a three-week window we prioritised topics whose evidence can be
measured fully on our VMs. The GPU/NPU driver identification required by the Unit 1 connection
is still covered by `neon-info` (Layer 3).

## Layer 3 — Commands and shortcuts

| Component | Owner | Support | Repository path |
|---|---|---|---|
| Mandatory command `neon-info` | Royner Baltodano Sánchez | Hernán Alonso Gutiérrez Quesada | `bin/neon-info` |
| Free command 1 & 2 | Hernán Alonso Gutiérrez Quesada | — | `bin/` |
| Free command 3 & 4 | Royner Baltodano Sánchez | — | `bin/` |
| Mandatory shortcuts | Royner Baltodano Sánchez | — | `dotfiles/i3/config` |
| Free shortcuts (3 each) | Each member | — | `dotfiles/i3/config`, `docs/cheatsheet.md` |
