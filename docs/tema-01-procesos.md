# Topic 1: Processes and scheduling
**Owner:** Royner Baltodano Sánchez  ·  **Support:** Hernán Alonso Gutiérrez Quesada

> Evidence sheet following Annex 2 of the assignment. Without measured data this topic is capped at 2/5.

**Requirement (A.4):** Own tool listing PID, PPID, state, nice, scheduling policy (SCHED_OTHER/FIFO/RR/IDLE) and CPU usage, able to change priority and policy. Identify the kernel scheduler (EEVDF on kernels >= 6.6) and explain it.

**Minimum evidence required:** Two or more CPU-bound processes pinned to the same core (`taskset`) with different nice values: measured CPU share vs. the kernel weight table (`sched_prio_to_weight`). Repeat with a real-time policy (`chrt`) and explain the difference.

## 1. What was implemented
<!-- Concrete description + paths in the repository -->

## 2. Operating-systems concept
<!-- Concept demonstrated + bibliographic reference -->
Reference: Silberschatz et al., *Operating System Concepts* 10th ed., ch. 3 (Processes) and ch. 5 (CPU Scheduling).

## 3. Measurement method
<!-- Tool, EXACT commands, conditions of the experiment, number of repetitions.
     Someone else must be able to copy-paste and reproduce. -->

```bash
# commands here
```

## 4. Results
<!-- Table or chart. Before/after or comparison between alternatives. Raw data in docs/evidence/tema-01/ -->

| Condition | Metric | Run 1 | Run 2 | Run 3 | Mean |
|---|---|---|---|---|---|
| | | | | | |

## 5. Interpretation
<!-- What do the data say? Do they match the theory? If not, why? -->
