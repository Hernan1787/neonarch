# Topic 2: Memory
**Owner:** Royner Baltodano Sánchez · **Support:** Hernán Alonso Gutiérrez Quesada

> Evidence sheet (Annex 2). Owner's run notes and full comparison: [`docs/tema2-swap-zram.md`](tema2-swap-zram.md); raw data: [`docs/evidence/tema2-neonarch-roy/`](evidence/tema2-neonarch-roy/); script: [`scripts/measure-swap-zram.sh`](../scripts/measure-swap-zram.sh).

## 1. What was implemented (on `neonarch-roy`, 2 GiB RAM)
| Item | Configuration |
|---|---|
| zram | `zram-generator` (`config/zram-generator.conf`): `zram0`, size = RAM/2 (≈ 970 MiB), `zstd`, **priority 100** |
| Disk swap | 2 GiB swapfile on the `@swap` btrfs subvolume, created with `btrfs filesystem mkswapfile` (NOCOW, uncompressed), priority −1 (default) |
| VM tuning | `config/sysctl.d/99-neonarch-zram.conf` (`vm.swappiness = 180`, `vm.page-cluster = 0`) |
| Measurement | `scripts/measure-swap-zram.sh`: `stress-ng --vm` + `vmstat`, with and without zram |

The kernel uses the swap area with the **highest priority first**: pages go to zram (compressed RAM, cost ≈ µs of CPU) before the swapfile (disk I/O, cost ≈ ms).

## 2. Operating-systems concept
Virtual memory: demand paging, page replacement and swapping, swap-space management, memory compression, thrashing and the OOM killer.
Silberschatz, Galvin & Gagne, *Operating System Concepts* 10th ed., ch. 10 (§10.2 demand paging, §10.4 page replacement, §10.6 thrashing, §10.7 memory compression) and §11.5 (swap-space management).

## 3. Measurement method
```bash
./scripts/measure-swap-zram.sh
```
Two runs of 180 s each, same load: `stress-ng --vm 1 --vm-bytes 3900M --vm-keep` on a VM with 2 GiB of RAM (stress-ng capped the worker at 1.76 GB of 1.61 GB available, so the run forces paging):
1. **without zram** (`swapoff /dev/zram0`, only the swapfile);
2. **with zram** (zram prio 100 + swapfile).
`vmstat -w 2` sampled every 2 s (100 samples per run); `free -h` and `swapon --show` before/after; stress-ng throughput.

## 4. Results (2026-11-12)
| Metric | Without zram | With zram | Change |
|---|---|---|---|
| mean `vmstat si` (KiB/s swapped in) | 15.5 | 23.6 | +52 % |
| mean `vmstat so` (KiB/s swapped out) | 226.0 | 80.6 | −64 % |
| mean `wa` (% I/O wait) | 0.0 | 0.0 | — |
| stress-ng throughput (bogo ops/s, real time) | 1908.7 | 1654.8 | −13 % |
| stress-ng total bogo ops (180 s) | 344 754 | 298 959 | −13 % |

`swapon --show` after the zram run: `/dev/zram0` 969.5 MiB, prio 100; `/swap/swapfile` 2 GiB, 68 MiB used, prio −1.

## 5. Interpretation
- **zram changes the paging profile rather than making the load faster.** With zram the swap-out rate fell by 64 % and the swap-in rate rose. Swapping a page to zram is cheap (a compression in RAM), so the kernel can evict and bring back pages more freely.
- **What `si`/`so` measure:** vmstat counts pages moved to and from *any* swap device, zram included, so these columns do not separate disk traffic from compressed-RAM traffic. The swapfile still ended with 68 MiB used, so part of the eviction reached the disk. A per-device split would need `/sys/block/zram0/mm_stat` and the swapfile usage sampled during the run (what `bin/neon-mem` shows).
- **CPU cost:** stress-ng did 13 % less work with zram, consistent with compressing and decompressing every page with zstd on a 2-vCPU VM. `wa` stayed at 0 in both runs because the virtual disk sits on the host's NVMe SSD, which hides the I/O penalty that zram avoids on slow disks.
- **No OOM kill** in either run: RAM + swap were enough for the 1.76 GB worker.
- **Trade-off:** zram pays off when the disk is slow or must not wear (laptops, SD/eMMC, low-RAM machines); with a fast disk and a busy CPU, as here, its benefit is smaller. A faster compressor (`lz4`) would reduce the CPU penalty at the cost of a lower compression ratio.
- **Limitations:** one run per scenario, a VM with a very fast virtual disk, and a synthetic load (stress-ng pages are highly compressible).
