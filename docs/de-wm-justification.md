# DE/WM Choice: i3 (Layer 1)

**Owner:** Royner Baltodano Sánchez

## Choice
**i3** (tiling window manager on X11) with i3status, rofi, xterm and dunst.

Terminal: we first used Alacritty (GPU/OpenGL-rendered) but it hung without drawing a window in the VM, because VirtualBox's VMSVGA adapter has no 3D acceleration. We replaced it with **xterm**, rendered on the CPU through X11, which also uses less memory.

## Why (qualitative)
- **Low resource usage:** i3 is a single process that only manages windows; there is no
  compositor, file manager or settings daemon running in the background. This matters on VMs
  with 4 GB of RAM where Topic 2 deliberately creates memory pressure.
- **Stable under virtualisation:** i3 runs on plain X11 and does not need GPU acceleration.
  Wayland compositors such as Hyprland require 3D acceleration that VirtualBox does not provide reliably.
- **Fully text-configured:** one plain-text config file, versioned in Git and symlinked by
  `install.sh`. This is what makes the distro reproducible.
- **Keyboard driven:** the mandatory shortcuts (A.5) map one-to-one onto i3 `bindsym` lines.

## Why (measured)
Compared against **XFCE** (lightweight traditional desktop), installed temporarily only for
this measurement (`sudo pacman -S xfce4` → measure → `sudo pacman -Rns xfce4`).

Method: `scripts/measure-desktop.sh <label>`. It waits 60 s after login, then takes 5 samples 10 s
apart of used memory (`MemTotal − MemAvailable` from `/proc/meminfo`), number of processes
(`/proc/[pid]`), and RSS/PSS of the user's processes (`ps`, `/proc/<pid>/smaps_rollup`).
Only one terminal is open. Raw data: `docs/evidence/desktop/measurements.csv`.

| Environment | Used memory (MiB, mean) | Total processes | User processes | User PSS (MiB) |
|---|---|---|---|---|
| i3 | | | | |
| XFCE | | | | |

## Interpretation
*(Fill in with the data: difference in MiB and processes, which processes XFCE adds — xfce4-panel,
xfdesktop, xfsettingsd, xfconfd, Thunar daemon… — and why that matters for our memory experiments.)*
