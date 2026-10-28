# Topic 7: Boot process
**Owner:** Hernán Alonso Gutiérrez Quesada  ·  **Support:** Royner Baltodano Sánchez

> Evidence sheet following Annex 2 of the assignment. Without measured data this topic is capped at 2/5.

**Requirement (A.4):** Full flow: UEFI firmware → systemd-boot → kernel → initramfs (mkinitcpio hooks) → systemd (targets) → login.

**Minimum evidence required:** `systemd-analyze`, `blame`, `critical-chain`; one measured boot-time optimisation (before/after). Live boot into `rescue.target` / `emergency.target` via kernel parameters.

## 1. What was implemented
<!-- Concrete description + paths in the repository -->

## 2. Operating-systems concept
<!-- Concept demonstrated + bibliographic reference -->
Reference: Silberschatz et al., ch. 2.9 (System Boot); bootup(7), systemd.special(7).

## 3. Measurement method
<!-- Tool, EXACT commands, conditions of the experiment, number of repetitions.
     Someone else must be able to copy-paste and reproduce. -->

```bash
# commands here
```

## 4. Results
<!-- Table or chart. Before/after or comparison between alternatives. Raw data in docs/evidence/tema-07/ -->

| Condition | Metric | Run 1 | Run 2 | Run 3 | Mean |
|---|---|---|---|---|---|
| | | | | | |

## 5. Interpretation
<!-- What do the data say? Do they match the theory? If not, why? -->
