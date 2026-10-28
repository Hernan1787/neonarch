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
*(To be completed by the team: the next time an AI answer is wrong, record it here with the exact error and how you detected it.)*

---

## Components built without AI
*(List them here if any.)*
