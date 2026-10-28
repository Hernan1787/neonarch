# Topic 2: Memory
**Owner:** Royner Baltodano Sánchez  ·  **Support:** Hernán Alonso Gutiérrez Quesada

> Evidence sheet following Annex 2 of the assignment. Without measured data this topic is capped at 2/5.

**Requirement (A.4):** Swap (swapfile in `@swap`) and zram (`zram-generator`) with justified priorities. Own real-time tool showing physical memory, swap, zram (compression ratio) and minor/major page faults per process.

**Minimum evidence required:** Memory pressure with `stress-ng --vm`: `vmstat` si/so, page faults and zram usage, **with and without zram**. Explain demand paging, swapping and the OOM killer if it triggers.

## 1. What was implemented
<!-- Concrete description + paths in the repository -->

## 2. Operating-systems concept
<!-- Concept demonstrated + bibliographic reference -->
Reference: Silberschatz et al., ch. 9 (Main Memory) and ch. 10 (Virtual Memory).

## 3. Measurement method
<!-- Tool, EXACT commands, conditions of the experiment, number of repetitions.
     Someone else must be able to copy-paste and reproduce. -->

```bash
# commands here
```

## 4. Results
<!-- Table or chart. Before/after or comparison between alternatives. Raw data in docs/evidence/tema-02/ -->

| Condition | Metric | Run 1 | Run 2 | Run 3 | Mean |
|---|---|---|---|---|---|
| | | | | | |

## 5. Interpretation
<!-- What do the data say? Do they match the theory? If not, why? -->
