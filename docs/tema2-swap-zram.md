# Tema 2 — Swap + zram evidence (neonarch-roy)

Generated: 2026-11-12T16:27:46-06:00
VM RAM: 2048 MB · workers: 1 · vm-bytes: 3900M · duration: 180s
Swapfile: /swap/swapfile (2G, NOCOW) · zram0: ram/2 (1G), zstd, prio 100

## Setup

- Swapfile on btrfs subvolume `@swap` (NOCOW, created with `btrfs filesystem mkswapfile`), priority -1.
- zram0 via `zram-generator`, size = ram/2, compression zstd, priority 100 (used first).
- Pressure: `stress-ng --vm 1 --vm-bytes 3900M --vm-keep --timeout 180s`.
- Monitor: `vmstat -w 2` (column averages over the run).

## Comparison

| Metric | Without zram | With zram | Delta | Interpretation |
|---|---|---|---|---|
| vmstat samples | 100 | 100 | | |
| avg `si` (KB/s) | 15.5 | 23.6 | +8 | swap-in rises: kernel uses the cheaper compressed swap more |
| avg `so` (KB/s) | 226.0 | 80.6 | -146 | **swap-out drops sharply: zram absorbs pages in RAM before hitting the disk** |
| avg `wa` (%) | 0.0 | 0.0 | 0 | I/O wait is 0 in both: the VM disk is fast (virtualized), so `wa` is not the right metric here |
| stress-ng bogo ops/s | 344754 | 298959 | -45795 | throughput drops slightly: zstd compression costs CPU |

## Conclusion

Enabling zram changes the memory profile rather than making everything faster:

- **Disk writes to the swapfile drop by ~65%** (`so` 226.0 → 80.6 KB/s). This is zram's main goal: keep swapped pages in compressed RAM (priority 100) and only spill to the btrfs swapfile when zram is full.
- **Swap-in rises slightly** (`si` 15.5 → 23.6 KB/s) because compressed swap is cheap enough that the kernel uses it more aggressively.
- **CPU cost is visible**: stress-ng throughput falls ~13% (`bogo ops/s` 344754 → 298959) because zstd compresses/decompresses on every page.
- **I/O wait is 0 in both runs** because the disk is virtualized and fast; on real hardware with an SSD/HDD, `wa` would be a stronger differentiator.

Trade-off: zram is worth it when disk I/O or disk wear is the bottleneck (laptops, SSDs, low-RAM VMs). It is less attractive when CPU is the bottleneck or the disk is already fast. A faster compressor (`lz4` or `zstd:1`) would reduce the CPU penalty at the cost of a larger zram footprint.

## Evidence

See `docs/evidence/tema2-neonarch-roy/`:
- `evidencia-vmstat-{sin,con}-zram.txt`
- `evidencia-stress-ng-{sin,con}-zram.txt`
- `evidencia-free-{sin,con}-zram.txt`
- `evidencia-swapon-{sin,con}-zram.txt`
