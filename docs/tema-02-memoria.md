# Topic 2: Memory
**Owner:** Royner Baltodano Sánchez · **Support:** Hernán Alonso Gutiérrez Quesada

## 1. What was implemented
| Item | File | Notes |
|---|---|---|
| zram (compressed swap in RAM) | `config/zram-generator.conf` → `/etc/systemd/zram-generator.conf` | 50 % of RAM, `zstd`, **priority 100** |
| Disk swapfile, 2 GiB | `scripts/tema02-setup-swap.sh` | on the `@swap` btrfs subvolume (NOCOW, uncompressed), **priority 10** |
| VM tuning for zram | `config/sysctl.d/99-neonarch-zram.conf` | `vm.swappiness=180`, `vm.page-cluster=0`, watermark tuning |
| Real-time monitor **`neon-mem`** | `bin/neon-mem` | RAM, swap devices + priorities, zram ratio, swap-in/out and major faults per second, top processes by page faults |

**Why these priorities:** the kernel always uses the swap area with the **highest priority first**. Swapping a page to zram costs one compression (µs, CPU), while swapping it to disk costs an I/O (ms). So zram absorbs the pressure first, and the disk swapfile is only the last resort before the OOM killer.

## 2. Operating-systems concept
Virtual memory: demand paging, page faults (minor = page already in RAM or zero page, major = must be read from disk/swap), page replacement, swapping, thrashing, and the OOM killer when RAM + swap run out.
Silberschatz et al., *Operating System Concepts* 10th ed., ch. 10 (Virtual Memory: §10.2 demand paging, §10.4 page replacement, §10.6 thrashing, §10.7 memory compression, §10.10 Linux), ch. 11.5 (swap-space management).

## 3. Measurement method
```bash
./install.sh                     # deploys zram + sysctl
./scripts/tema02-setup-swap.sh   # swapfile; shows swapon --show and zramctl
./scripts/tema02-measure.sh      # ~3 min
neon-mem                         # watch it live in another terminal during the test
```
Two scenarios, same load: `stress-ng --vm 2 --vm-keep` allocating **MemAvailable + 1.5 GiB** for 60 s (more than fits in RAM):
1. **zram**: zram (prio 100) + swapfile (prio 10)
2. **nozram**: `swapoff /dev/zram0`, only the swapfile on disk

Recorded per scenario: `vmstat 1` (columns `si`/`so`), deltas of `/proc/vmstat` `pswpin`/`pswpout`/`pgmajfault`, zram `mm_stat` (original vs compressed size), stress-ng throughput (bogo ops/s), and OOM-killer messages in the kernel log. Output: `docs/evidence/tema-02/`.

## 4. Results
<!-- paste docs/evidence/tema-02/summary.md + zram ratio from zram-zram.txt + a few vmstat lines -->

## 5. Interpretation
<!-- Expected: with zram the work (bogo ops/s) is higher and major faults lower, because swap-in
is a decompression instead of a disk read; stress-ng data is very compressible, so the zram ratio
is high (say so: real workloads compress ~2-3:1). Without zram, si/so go to the disk and the
system thrashes. Mention whether the OOM killer appeared. -->
