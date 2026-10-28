# Topic 4: Service management (systemd)
**Owner:** Hernán Alonso Gutiérrez Quesada  ·  **Support:** Royner Baltodano Sánchez

> Evidence sheet following Annex 2 of the assignment. Without measured data this topic is capped at 2/5.

**Requirement (A.4):** Own systemd service with dependencies (`After=`, `Wants=`), restart policy, resource limits (`CPUQuota=`, `MemoryMax=`) and a timer or socket activation.

**Minimum evidence required:** `systemctl status`, `journalctl -u`, `systemd-cgls` showing its cgroup; proof the CPU/memory limit is enforced under load; automatic restart after a provoked failure.

## 1. What was implemented
<!-- Concrete description + paths in the repository -->

## 2. Operating-systems concept
<!-- Concept demonstrated + bibliographic reference -->
Reference: Silberschatz et al., ch. 2 (Operating-System Structures, system services) and ch. 3 (process creation/termination); systemd.resource-control(5).

## 3. Measurement method
<!-- Tool, EXACT commands, conditions of the experiment, number of repetitions.
     Someone else must be able to copy-paste and reproduce. -->

```bash
# commands here
```

## 4. Results
<!-- Table or chart. Before/after or comparison between alternatives. Raw data in docs/evidence/tema-04/ -->

| Condition | Metric | Run 1 | Run 2 | Run 3 | Mean |
|---|---|---|---|---|---|
| | | | | | |

## 5. Interpretation
<!-- What do the data say? Do they match the theory? If not, why? -->
