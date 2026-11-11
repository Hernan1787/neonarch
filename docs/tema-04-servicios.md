# Topic 4: Service management (systemd)
**Owner:** Hernán Alonso Gutiérrez Quesada

## 1. What was implemented
**`neon-health.service`**: a long-running daemon that every 10 s appends one line (load, `MemAvailable`, number of processes, its own RSS, all read from `/proc`) to `/var/lib/neon-health/health.csv`. It also has test hooks: `SIGUSR1` burns CPU for 30 s and `SIGUSR2` allocates memory without limit. A timer runs **`neon-health-report.service`** every hour to summarise the last 24 h in the journal.

| File | Purpose |
|---|---|
| `systemd/scripts/neon-health` | the daemon (Python), deployed to `/usr/local/lib/neonarch/` |
| `systemd/system/neon-health.service` | the service unit |
| `systemd/system/neon-health-report.service` | oneshot report |
| `systemd/system/neon-health-report.timer` | `OnBootSec=2min`, `OnUnitActiveSec=1h`, `Persistent=true` |
| `config/services.txt` | `install.sh` enables the service and the timer |

Key directives of `neon-health.service`:

| Directive | Value | Meaning |
|---|---|---|
| `After=` | `local-fs.target` | start only after the filesystems are mounted (ordering) |
| `Wants=` | `neon-health-report.timer` | pull in the timer as a weak dependency |
| `Restart=` / `RestartSec=` | `on-failure` / `3` | restart after a crash, kill or OOM, but not after a clean stop |
| `StartLimitIntervalSec=` / `StartLimitBurst=` | `60` / `5` | give up after 5 restarts in 60 s (prevents a restart loop) |
| `CPUQuota=` | `20%` | the cgroup may use at most 20 ms of CPU every 100 ms |
| `MemoryMax=` / `MemorySwapMax=` | `64M` / `0` | hard memory limit; above it the kernel OOM-kills inside the cgroup |
| `DynamicUser=` / `StateDirectory=` | `yes` / `neon-health` | runs as an ephemeral unprivileged user; only its state dir is writable |
| `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes`, `NoNewPrivileges=yes` | | sandboxing (least privilege, also relevant to Topic 9) |

## 2. Operating-systems concept
Process creation and termination, signals, resource allocation and accounting, and protection. systemd puts each service in its own **cgroup v2**, and the kernel enforces the limits through the CPU controller (CFS/EEVDF bandwidth control: quota per period) and the memory controller (memcg OOM killer).
Silberschatz et al., *Operating System Concepts* 10th ed., ch. 3 (Processes), ch. 5 (CPU Scheduling), ch. 10 (Virtual Memory, §10.6 Thrashing / allocation of frames); `systemd.resource-control(5)`, `systemd.service(5)`.

## 3. Measurement method
```bash
./scripts/tema04-measure.sh
```
The script:
1. saves `systemctl status`, `systemd-cgls -u neon-health.service` and the effective limits (`systemctl show`);
2. **CPU:** sends `SIGUSR1` (30 s CPU burn) and, every second for 25 s, reads `usage_usec` from the cgroup file `/sys/fs/cgroup/system.slice/neon-health.service/cpu.stat`. CPU % of one core = Δusage_usec / 10 000. It repeats the test **without** the quota (`systemctl set-property --runtime neon-health CPUQuota=`) as the comparison, then restores 20 %;
3. **Memory:** sends `SIGUSR2` and records the journal: the kernel OOM-kills the process when it reaches 64 MiB, and systemd restarts it (`NRestarts` grows);
4. **Restart policy:** `systemctl kill -s SIGKILL` and checks that the service comes back after `RestartSec=3`.

Output: `docs/evidence/tema-04/` (`cpu-with-quota.csv`, `cpu-without-quota.csv`, `oom-journal.txt`, `kill-journal.txt`, `summary.md`, …).

## 4. Results
<!-- Paste docs/evidence/tema-04/summary.md and the key journal lines here -->

## 5. Interpretation
<!-- With the real data. Expected: with the quota the burn stays around 20 % of one core
(the scheduler throttles the cgroup once it has used 20 ms of each 100 ms period); without it,
close to 100 % of one core (it is single-threaded). The OOM kill happens inside the cgroup only,
so the rest of the system is unaffected. -->
