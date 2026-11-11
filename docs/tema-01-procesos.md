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
Measured on `neonarch-hernan`, kernel **7.2.15-arch1-1**, 2 vCPU, 2026-11-10. 3 runs × 20 s. Raw data: `docs/evidence/tema-01/`.

**A. Three CPU-bound loops on CPU 0 (fair class, EEVDF)**

| nice | weight | expected share | run 1 | run 2 | run 3 | mean |
|---|---|---|---|---|---|---|
| 0 | 1024 | 69.7 % | 69.1 % | 69.0 % | 69.1 % | **69.8 %** of the shared core* |
| 5 | 335 | 22.8 % | 22.6 % | 22.5 % | 22.6 % | **22.8 %** |
| 10 | 110 | 7.5 % | 7.4 % | 7.3 % | 7.4 % | **7.4 %** |

\* the per-run columns are % of one core; the mean column is the *share* among the three (normalised to 100 %), which is what the weights predict.

**B. SCHED_FIFO priority 10 vs SCHED_OTHER nice 0 on CPU 0**

| run | SCHED_FIFO | SCHED_OTHER |
|---|---|---|
| 1 | 94.1 % | 5.0 % |
| 2 | 94.0 % | 5.0 % |
| 3 | 94.0 % | 5.0 % |

Environment: `sched_rt_runtime_us = 1000000`, `sched_rt_period_us = 1000000`, `sched_autogroup_enabled = 1`.

## 5. Interpretation
- **A matches the theory to ±0.1 percentage points.** EEVDF does not give "priority" in the old sense: every runnable task gets a share proportional to its weight. Its virtual runtime advances at `delta × 1024 / weight`, so a nice 10 task's clock runs ~9.3× faster than a nice 0 task's, and it becomes *ineligible* sooner. Each nice step is ≈ ×1.25 in weight (≈ 10 % CPU difference between neighbours). Note that **nice 10 still runs** (7.4 %): the fair class never starves a task.
- **B shows the separation between scheduling classes.** The `SCHED_FIFO` task always preempts the fair one: a real-time task runs until it blocks or yields, whatever its nice. The interesting part is *why the normal task still got exactly 5 %*. On this kernel `sched_rt_runtime_us = sched_rt_period_us = 1 000 000`, so the classic **RT throttling is disabled** (it used to reserve 5 % via 950 000/1 000 000). The 5 % now comes from the **fair server**, a `SCHED_DEADLINE` server added to Linux in the 6.12 series. On each CPU it reserves **50 ms of every 1 s** for fair-class tasks when real-time tasks would otherwise starve them. Verification: `sudo cat /sys/kernel/debug/sched/fair_server/cpu0/{runtime,period}` → `50000000` / `1000000000` ns.
- The remaining ~1 % of CPU 0 is used by other processes and interrupts (kworkers, `neon-health`, i3).
- **Limitations:** a 2-vCPU VM (the hypervisor can also steal time), 20 s windows, and only CPU-bound loops (I/O-bound tasks would also be affected by wake-up latency, which EEVDF improves with shorter virtual deadlines).
