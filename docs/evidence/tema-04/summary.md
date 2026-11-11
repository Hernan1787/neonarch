| Test | Result |
|---|---|
| Mean CPU while burning, CPUQuota=20% | 19.8 % of one core |
| Mean CPU while burning, no quota | 101.2 % of one core |
| OOM kill at MemoryMax=64M | restarted, NRestarts 0 -> 1 |
| SIGKILL of main process | restarted, NRestarts 1 -> 2 |
