# NeonArch — Keyboard Shortcuts

`Super` = Windows key. Config: `dotfiles/i3/config`.

## Mandatory shortcuts (A.5)

| Shortcut | Action | Designed by |
|---|---|---|
| `Super + Enter` | Open terminal (xterm) | Assignment |
| `Super + W` / `Super + Q` | Close the active window | Assignment |
| `Super + D` | Application launcher (rofi) | Assignment |
| `Super + 1…9` | Switch to workspace 1…9 | Assignment |

## Free shortcuts — exactly 3 per member

| Shortcut | Action | Uses (OS interface / own command) | Designed by |
|---|---|---|---|
| `Super + I` | System stats HUD: `neon-info` in a floating terminal | `neon-info` (`/proc`, `/sys`, syscalls) | Hernán Alonso Gutiérrez Quesada |
| `Super + B` | "Game mode" for the focused window: nice −5 for all its threads + highest I/O priority | `neon-boost --focused` (`xdotool` → PID, `setpriority(2)`, `ioprio_set(2)`; Topic 1) | Hernán Alonso Gutiérrez Quesada |
| `Super + Shift + S` | Manual btrfs snapshot of `/` + notification with its number | `snapper -c root create` (Topic 3) | Hernán Alonso Gutiérrez Quesada |
| `Super + Shift + L` | Lock the screen | `i3lock -c 000000` | Royner Baltodano Sánchez |
| `Super + Shift + K` | Terminal calculator in a new xterm | own command `neonarch-calc` | Royner Baltodano Sánchez |
| `Super + Shift + P` | Screenshot of a selected area to `~/capturas/` | `maim -s` | Royner Baltodano Sánchez |

## Standard i3 navigation (reference, not graded)

| Shortcut | Action |
|---|---|
| `Super + Shift + 1…9` | Move window to workspace |
| `Super + ←↓↑→` | Change focus |
| `Super + Shift + ←↓↑→` | Move window |
| `Super + H` / `Super + V` | Next window splits horizontally / vertically |
| `Super + F` | Fullscreen |
| `Super + S` / `T` / `E` | Stacking / tabbed / split layout |
| `Super + Shift + Space` | Toggle floating |
| `Super + R` | Resize mode (arrows, Esc to exit) |
| `Super + Shift + C` / `R` | Reload / restart i3 |
| `Super + Shift + E` | Exit session |
