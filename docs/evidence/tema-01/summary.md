# Topic 1 results

Environment: `{'kernel': '7.2.15-arch1-1', 'sched_rt_runtime_us': '1000000', 'sched_rt_period_us': '1000000', 'sched_autogroup_enabled': '1', 'cpus': 2}`

## A. Three CPU-bound loops on CPU 0, 20 s × 3 runs

| nice | weight | expected share | measured share (mean ± sd) |
|---|---|---|---|
| 0 | 1024 | 69.7 % | 69.8 ± 0.0 % |
| 5 | 335 | 22.8 % | 22.8 ± 0.0 % |
| 10 | 110 | 7.5 % | 7.4 ± 0.0 % |

## B. SCHED_FIFO (prio 10) vs SCHED_OTHER (nice 0) on CPU 0

| class | expected | measured (mean of runs) |
|---|---|---|
| SCHED_FIFO | ≤ 100 % (RT throttling) | 94.0 % |
| SCHED_OTHER | ≥ 0 % | 5.0 % |
