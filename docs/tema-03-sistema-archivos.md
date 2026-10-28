# Topic 3: Filesystem (btrfs)
**Owner:** Hernán Alonso Gutiérrez Quesada  ·  **Support:** Royner Baltodano Sánchez

> Evidence sheet following Annex 2 of the assignment. Without measured data this topic is capped at 2/5.

**Requirement (A.4):** btrfs root with subvolume layout (`@`, `@home`, `@snapshots`, `@var_log`, `@pkg`, `@swap`), justification of advantages/disadvantages, automatic snapshots with snapper (timer + pacman pre/post).

**Minimum evidence required:** `fio` benchmark btrfs vs. ext4 (loop image): sequential and random 4 KiB, read and write. Live demo: destructive change → snapshot rollback.

## 1. What was implemented
<!-- Concrete description + paths in the repository -->

## 2. Operating-systems concept
<!-- Concept demonstrated + bibliographic reference -->
Reference: Silberschatz et al., ch. 13 (File-System Interface), ch. 14 (File-System Implementation), ch. 15 (File-System Internals).

## 3. Measurement method
<!-- Tool, EXACT commands, conditions of the experiment, number of repetitions.
     Someone else must be able to copy-paste and reproduce. -->

```bash
# commands here
```

## 4. Results
<!-- Table or chart. Before/after or comparison between alternatives. Raw data in docs/evidence/tema-03/ -->

| Condition | Metric | Run 1 | Run 2 | Run 3 | Mean |
|---|---|---|---|---|---|
| | | | | | |

## 5. Interpretation
<!-- What do the data say? Do they match the theory? If not, why? -->
