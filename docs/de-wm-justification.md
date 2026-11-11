# DE/WM Choice: i3 (Layer 1)

**Owner:** Hernán Alonso Gutiérrez Quesada

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
Both sessions were started **the same way**: fresh reboot, login on tty1, `~/.bash_profile` → `startx`
→ `~/.xinitrc`, which picks the session from `~/.config/neonarch/session` (`i3` by default, `xfce` for
the test). The only window open was one **xterm** running the script (in XFCE it was opened with Alt+F2).

Method: `scripts/measure-desktop.sh <label>`. It waits 60 s after login, then takes 5 samples 10 s
apart of used memory (`MemTotal − MemAvailable` from `/proc/meminfo`), number of processes
(`/proc/[pid]`), and RSS/PSS of the user's processes (`ps`, `/proc/<pid>/smaps_rollup`).
Only one terminal is open. Raw data: `docs/evidence/desktop/measurements.csv`.

| Environment | Used memory (MiB) | Available (MiB) | Total processes | User processes | User RSS (MiB) | User PSS (MiB) |
|---|---|---|---|---|---|---|
| **i3** | **598** | 3290 | 137 | **25** | 245 | **143** |
| XFCE 4.20 | 845 | 3043 | 145 | 41 | 776 | 356 |
| **XFCE − i3** | **+247 (+41 %)** | −247 | +8 | **+16** | +531 | **+213 (2.5×)** |

Means of 5 samples (10 s apart, after 60 s idle) on `neonarch-hernan` (4 GiB VM, kernel 7.2.15), 2026-11-11. The samples within each session varied by less than 15 MiB. Raw data: `docs/evidence/desktop/measurements.csv`; process lists: `processes-{i3,xfce}-neonarch-hernan.txt`; `free -m`: `free-*.txt`.

### Where the memory goes (RSS per process, from `processes-*.txt`)
| Process | i3 session | XFCE session |
|---|---|---|
| X server (`Xorg`) | 82 MB | 92 MB |
| Window manager | `i3` 44 MB | `xfwm4` 46 MB |
| Session manager | — | `xfce4-session` 61 MB |
| Desktop / wallpaper / icons | `xsetroot` (exits) | `xfdesktop` 57 MB |
| Settings daemons | — | `xfsettingsd` 52 MB, `dconf-service` 6 MB |
| Panel / bar | `i3bar` 17 MB + `i3status` 6 MB | `xfce4-panel` 46 MB + 2 plugin wrappers 67 MB |
| File manager daemon | — | `Thunar --daemon` 30 MB |
| Power manager, polkit agent, accessibility bus | — | 29 + 28 + 16 MB |
| Notifications | `dunst` 12 MB | `dunst` 12 MB |
| **Measurement artefacts** | — | `xfce4-appfinder` 42 MB (Alt+F2 launcher, stayed running as the parent of xterm); one `VBoxClient` helper 112 MB (≤ 4.5 MB in the i3 session) |

## Interpretation
- **XFCE runs 16 more user processes and its session takes 2.5× the proportional memory (PSS 356 vs 143 MiB).** The extra processes are XFCE's always-running components: session manager, desktop, settings daemons, panel and its plugins, Thunar daemon, power manager, polkit agent, accessibility bus. In i3 each of those roles is either absent or done by one small program (i3, i3bar/i3status, dunst).
- **Honest correction of the raw difference.** Of the +247 MiB of system-wide used memory, part is not XFCE itself: `xfce4-appfinder` (42 MB RSS) was only there because we used Alt+F2 to open the terminal, and one VirtualBox guest helper (`VBoxClient`) grew to 112 MB in the XFCE session while it stayed under 4.5 MB in i3. We did not investigate why (it is VirtualBox's clipboard/display integration, not part of XFCE). Even excluding both, XFCE's own components add about **+380 MB of RSS** (776 − 112 − 42 = 622 MB vs 245 MB), i.e. still about **2.5×** the i3 session.
- **PSS is the fair metric.** RSS counts shared libraries (GTK, glib, cairo) once **per process**, which inflates it when many GTK programs run. PSS (*proportional set size*) divides each shared page among the processes that map it, so the sum is the real memory of the session.
- **Total processes differ by only 8** because most of the ~140 processes are kernel threads (`kworker`, `ksoftirqd`…) and system services, the same in both sessions.
- **Why it matters for this project:** Topic 2 deliberately creates memory pressure on a 4 GiB VM, and Topics 1 and 4 measure CPU shares. With i3 the baseline is lower and there are 16 fewer background processes that could wake up and disturb the measurements.
- **Trade-off:** XFCE gives a complete point-and-click desktop (file manager, settings panels, power management). i3 requires learning keyboard shortcuts (`docs/cheatsheet.md`), which is acceptable, and even desirable, for a distribution built to study the OS from the terminal.
