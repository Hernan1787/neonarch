| Workload | FS | MiB/s (mean ± sd of runs) | IOPS | mean latency (µs) | runs |
|---|---|---|---|---|---|
| seqread | btrfs | 1825.6 ± 28.4 | 1826 | 8750 | 3 |
| seqread | ext4 | 1943.9 ± 15.1 | 1944 | 8206 | 3 |
| seqwrite | btrfs | 165.4 ± 34.7 | 165 | 99990 | 3 |
| seqwrite | ext4 | 634.8 ± 77.5 | 635 | 25351 | 3 |
| randread | btrfs | 104.2 ± 6.2 | 26683 | 575 | 3 |
| randread | ext4 | 105.9 ± 4.9 | 27111 | 583 | 3 |
| randwrite | btrfs | 27.2 ± 0.1 | 6955 | 2291 | 3 |
| randwrite | ext4 | 86.3 ± 4.1 | 22101 | 717 | 3 |
