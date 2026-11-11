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
Measured on `neonarch-hernan` (kernel 7.2.15-arch1-1, 2 vCPU, 4 GiB) on 2026-11-10. Raw data: `docs/evidence/tema-04/`.

| Test | Result |
|---|---|
| Mean CPU of the cgroup while burning, `CPUQuota=20%` (25 one-second samples) | **19.8 %** of one core |
| Mean CPU while burning, quota removed at runtime | **101.2 %** of one core |
| `SIGUSR2` → allocate beyond `MemoryMax=64M` | OOM-killed inside the cgroup, **restarted automatically** (NRestarts 0 → 1) |
| `SIGKILL` of the main process | **restarted automatically** after `RestartSec=3` (NRestarts 1 → 2) |

Other evidence: `status.txt` (active, cgroup tree, timer), `cgls.txt`, `limits.txt` (`CPUQuotaPerSecUSec=200ms`, `MemoryMax=67108864`, `DynamicUser=yes`), `oom-journal.txt`, `kill-journal.txt`, `ps-user.txt` (the daemon runs as a dynamic, unprivileged user, not root).

## 5. Interpretation
- **CPU limit.** A single CPU-bound thread would use a whole core (101.2 % without limit; the extra 1.2 % is sampling jitter of the 1 s windows). With `CPUQuota=20%` systemd writes `cpu.max = 20000 100000` to the cgroup: in every 100 ms period the group may run 20 ms, then the scheduler **throttles** it until the next period. The measured 19.8 % matches the configured 20 % within 1 %. The process is not slowed by a lower priority (its nice is still 0): it is limited by **bandwidth control**, a hard cap that also applies when the CPU is otherwise idle.
- **Memory limit.** `MemoryMax=64M` (`memory.max`) is enforced by the memory controller. When the daemon tried to go past it, reclaim could not free enough (no swap allowed: `MemorySwapMax=0`), so the kernel ran the OOM killer **only inside that cgroup**. The rest of the system was untouched, which is the isolation that cgroups provide.
- **Restart policy.** In both failures (OOM kill, SIGKILL) the unit ended with a non-success result, so `Restart=on-failure` brought it back after 3 s, and `NRestarts` counts it. A clean `systemctl stop` would *not* restart it, and `StartLimitBurst=5` in 60 s prevents an infinite crash loop.
- **Least privilege.** `DynamicUser=yes` plus `ProtectSystem=strict` means that even if the daemon were compromised it could only write to `/var/lib/neon-health`.
