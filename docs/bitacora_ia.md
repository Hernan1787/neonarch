# AI Usage Log (Annex 3)

> Course rule: AI is not forbidden; it is **declared and documented**.
> At least one entry per topic where AI was used, written by the topic owner.
> At least **two documented cases** of AI errors or inaccuracies detected by the team.
> If a component was built without AI, state it explicitly at the end.

---

### Entry 1
| Field | Content |
|---|---|
| Date · member | 2026-10-22 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Project-wide (choice of alternative) |
| Purpose | Explore alternatives |
| Summarised query | "Which alternative of the II Project should we choose?" (shared only the Telegram message, not the full assignment) |
| Result obtained | Recommended Alternative B, arguing reuse of our I Project infrastructure. |
| Validated / corrected / discarded | **Discarded.** The team chose Alternative A. The recommendation was made without reading the full assignment; the assignment states both alternatives have the same level of demand. |
| How it was validated | Read the full assignment (Part I, "Equivalencia de exigencia"). |

### Entry 2 — ⚠️ AI error #1
| Field | Content |
|---|---|
| Date · member | 2026-10-25 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Project-wide (getting started) |
| Purpose | Plan the first steps |
| Summarised query | "How do we start?" (before sharing the assignment document) |
| Result obtained | Proposed building an installable ISO with `archiso` (copy the `releng` profile, edit `packages.x86_64`, run `mkarchiso`). |
| Validated / corrected / discarded | **Discarded — incorrect for this assignment.** Section A.1 says explicitly that generating an installable ISO is *not* requested; the focus is manual installation, configuration, scripts and instrumentation. Following the advice would have wasted days on an unrequested deliverable. |
| How it was validated | Read assignment section A.1; the AI corrected itself once it was given the document. |

### Entry 3
| Field | Content |
|---|---|
| Date · member | 2026-10-27 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Layer 1 (installation guide, `install.sh`, dotfiles) and Layer 3 (`neon-info`) |
| Purpose | Generate a first version of the repository structure and scripts |
| Summarised query | "Build the repository skeleton, the installation guide with the reason for each command, an idempotent bootstrap and the mandatory command." |
| Result obtained | `docs/instalacion.md`, `install.sh`, `pkglist.txt`, i3/alacritty/rofi dotfiles, `bin/neon-info`, evidence-sheet templates. |
| Validated / corrected / discarded | *(fill in after testing on the VMs: what worked, what had to be changed)* |
| How it was validated | `shellcheck` on all scripts; `install.sh` run twice in a test environment → second run reported 0 changes (idempotent); `neon-info` executed and each value compared with `free -m`, `lscpu`, `lspci -k`, `findmnt /`. *(Pending: execution on both Arch VMs, logs in `logs/`.)* |

### Entry 4 — ⚠️ AI error #2
| Field | Content |
|---|---|
| Date · member | 2026-10-28 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Layer 1 / Layer 3 (`dotfiles/i3/config`) |
| Purpose | Generate the i3 configuration with the mandatory shortcuts |
| Summarised query | "Write the i3 config with Super+Enter, Super+W/Q, Super+D and Super+1..9." |
| Result obtained | A config with explanatory comments at the end of each line, e.g. `set $mod Mod4   # Super (Windows key)` and `bindsym $mod+w kill   # close active window`. |
| Validated / corrected / discarded | **Corrected.** On first login i3 showed *"You have an error in your i3 config file!"* and no shortcut worked. i3 does **not** support trailing comments: `$mod` became the literal text `Mod4 # Super (Windows key)`, so every `bindsym $mod+…` was invalid. Fixed by moving every comment to its own line. |
| How it was validated | `i3 -C -c dotfiles/i3/config` (config check mode) printed the parse errors pointing at line 9; after the fix it prints nothing and i3 starts without the error bar. Reference: i3 User's Guide, section "Comments" (comments must start at the beginning of a line). |

### Entry 5 — ⚠️ AI error #3
| Field | Content |
|---|---|
| Date · member | 2026-10-28 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Layer 1 (desktop: terminal for `Super+Enter`) |
| Purpose | Choose the terminal emulator |
| Summarised query | Part of the dotfiles generation (entry 3). |
| Result obtained | Chose Alacritty, assuming that software OpenGL (Mesa llvmpipe) would be enough inside the VM. |
| Validated / corrected / discarded | **Discarded.** In the VirtualBox VM (VMSVGA, no 3D) Alacritty never drew a window: each `Super+Enter` left a hung process (21 of them, RAM 178 MiB → 1.6 GiB), forcing `LIBGL_ALWAYS_SOFTWARE=1` did not help and the X display ended up black. Replaced by xterm, rendered on the CPU. |
| How it was validated | From tty2: `sudo showkey -k` (Super = keycode 125 arrives, so the shortcut was fine), `pgrep -a alacritty` (21 processes), `neon-info --short` (RAM growth). After switching to xterm the shortcut opens a terminal immediately. |

### Entry 6
| Field | Content |
|---|---|
| Date · member | 2026-11-02 / 2026-11-09 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Layer 2 Topics 1, 3, 4, 6, 7 (Hernán) and first drafts for Topics 2, 9 (Royner); Layer 3 commands `neon-ps`, `neon-boost`, `neon-net`, `neon-mem`; shortcuts |
| Purpose | Generate implementation and measurement scripts and evidence-sheet skeletons |
| Summarised query | "Prepare each topic so that it can be executed and measured on the VM: configuration, measurement script and evidence sheet." |
| Result obtained | `systemd/` units + `neon-health` daemon, snapper/fio/rollback scripts, `tema01-experiment.py`, Topic 7 boot measurement/optimisation, pacman hook + PKGBUILD, zram/swap config, nftables/SSH/sudoers/ACL setup and tests. |
| Validated / corrected / discarded | *(each owner fills in after running on their VM: what worked, what was changed, and that they can explain every line)* |
| How it was validated | Before delivery: `shellcheck` on every script, `i3 -C` on the i3 config, `visudo -c` on the sudoers drop-ins, `nft -c` on the firewall, local runs of `neon-ps`, `neon-boost`, `neon-net`, `neon-mem`, the `neon-health` daemon (CPU burn and memory hog) and `tema01-experiment.py` (measured shares 69.9/22.8/7.3 % vs expected 69.7/22.8/7.5 %). Final validation = the measurements on the Arch VMs. |

### Entry 7 — ⚠️ AI error #4
| Field | Content |
|---|---|
| Date · member | 2026-11-10 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Topic 3 (`scripts/tema03-fio-bench.sh`) |
| Purpose | Fair btrfs vs ext4 benchmark inside one VM |
| Summarised query | Part of entry 6: "benchmark btrfs against ext4 with fio". |
| Result obtained | The ext4 side used a loop image mounted with `mount -o loop` (buffered loop device). |
| Validated / corrected / discarded | **Corrected.** The first run gave ext4 5785 MiB/s sequential read and 217 914 random-read IOPS (71 µs): impossible for the virtual disk, which gave btrfs 1826 MiB/s and 26 683 IOPS. `O_DIRECT` only bypassed ext4's cache; the loop driver still read the image through the page cache, so ext4 was measuring **RAM**. Fixed by creating the loop device with `losetup --direct-io=on`. The biased JSONs are kept in `docs/evidence/tema-03/fio/discarded-buffered-loop/` as evidence of the problem. |
| How it was validated | Sanity check of the numbers against the hardware (RAM-speed results on a disk benchmark), `losetup -l` showing `DIO 1` in the re-run (`setup-ext4.txt`). |

### Entry 8 — ⚠️ AI error #5
| Field | Content |
|---|---|
| Date · member | 2026-11-11 · Hernán Alonso Gutiérrez Quesada |
| Tool | Claude (Anthropic) |
| Component | Topic 3 (`scripts/tema03-rollback-demo.sh`) |
| Purpose | Live demo: remove a package, then roll the files back from the snap-pac snapshot |
| Summarised query | Part of entry 6. |
| Result obtained | Step 3 ("htop no longer exists") printed `/usr/bin/htop` for `command -v htop`, although `snapper status 20..21` showed the file as deleted (`-..... /usr/bin/htop`). |
| Validated / corrected / discarded | **Corrected.** bash keeps a hash table of the paths of commands it has already executed (htop ran in step 1), and `command -v` answers from it without checking the file. The demo was technically right but would have shown the opposite of the truth during the defence. Fixed with `hash -r` before each command, plus `ls -l /usr/bin/htop` as direct proof and `pacman -Qkk htop` after the rollback. |
| How it was validated | Comparing the step 3 output with `snapper status` of the same transaction; re-running the demo. |

---

## Components built without AI
*(List them here if any.)*
