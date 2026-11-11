# Topic 1: Processes and scheduling
**Owner:** Hernán Alonso Gutiérrez Quesada

## 1. What was implemented
- **`neon-ps`** (`bin/neon-ps`, also packaged in `neonarch-tools`): lists PID, PPID, user, state, nice, scheduling policy, real-time priority, the CPU the process last ran on and %CPU (two samples of `utime+stime` from `/proc/<pid>/stat`, 1 s apart). It also changes a process:
  - `neon-ps nice PID N` → `setpriority(2)`
  - `neon-ps policy PID other|batch|idle|fifo|rr [prio]` → `sched_setscheduler(2)`
  - `neon-ps pin PID CPU` → `sched_setaffinity(2)`
- **Experiment** `scripts/tema01-experiment.py`: pins CPU-bound loops to one core and measures how the scheduler shares it.
- Related own command: **`neon-boost`** (raises nice and I/O priority of every thread of a process; shortcut `Super+B`).

### The kernel scheduler
`neon-info` reports **EEVDF** (*Earliest Eligible Virtual Deadline First*), the fair scheduler of Linux since 6.6 (kernel here: 7.2). It replaced CFS. Each runnable task accumulates *virtual runtime* at a rate inversely proportional to its **weight**, which comes from its nice value (`sched_prio_to_weight[]`: nice 0 = 1024, each nice step ≈ ×1.25). Among the tasks that are *eligible* (have not received more than their fair share), it runs the one with the earliest *virtual deadline* (= eligible time + time slice / weight), which also gives better latency to tasks with short slices. Real-time classes (`SCHED_FIFO`, `SCHED_RR`) always run before the fair class. To stop a runaway RT task from freezing the machine, they are throttled to `sched_rt_runtime_us / sched_rt_period_us` = 950 000 / 1 000 000 µs (95 %).

## 2. Operating-systems concept
Process states, PCB, CPU scheduling: priority, proportional-share (fair) scheduling, real-time scheduling, processor affinity.
Silberschatz et al., *Operating System Concepts* 10th ed., ch. 3 (Processes) and ch. 5 (CPU Scheduling: §5.3 algorithms, §5.5 multiprocessor/affinity, §5.6 real-time, §5.7.1 Linux scheduling).

## 3. Measurement method
```bash
sudo python3 scripts/tema01-experiment.py     # RUNS=3, 20 s per run
```
- **A. Fair class:** three `while :; do :; done` loops pinned to **CPU 0** (`sched_setaffinity`) with nice **0, 5 and 10** (`setpriority`), so they compete for one core. For 20 s we read `utime+stime` from `/proc/<pid>/stat`. Expected share = weight / Σweights = 1024/1469, 335/1469, 110/1469 = **69.7 %, 22.8 %, 7.5 %**.
- **B. Real-time vs fair:** one loop with `SCHED_FIFO` priority 10 and one normal loop (nice 0), both on CPU 0. Expected: FIFO ≈ 95 % (RT throttling), normal ≈ 5 %.
- 3 repetitions each. Raw data: `docs/evidence/tema-01/a-nice-shares.csv`, `b-fifo-vs-other.csv`. Table: `summary.md`.
- `neon-ps -p <PID>` during the run shows nice, policy and `CPU# 0` for the loops.

## 4. Results
<!-- paste docs/evidence/tema-01/summary.md -->

## 5. Interpretation
<!-- Compare measured vs expected shares. The small difference comes from other processes that
also run on CPU 0 and from the 20 s window. Explain why nice 10 still gets CPU (no starvation in
the fair class) but the normal loop almost starves next to SCHED_FIFO, and why it still gets ~5 %. -->
