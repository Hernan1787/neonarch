# Topic 3: Filesystem (btrfs)
**Owner:** Hernán Alonso Gutiérrez Quesada

## 1. What was implemented
- **Root filesystem: btrfs** (not ext4), created during the manual install (`docs/instalacion.md`, steps 3–5), with this subvolume layout:

| Subvolume | Mount point | Why separate |
|---|---|---|
| `@` | `/` | the system; this is what we snapshot and roll back |
| `@home` | `/home` | user files survive a system rollback |
| `@snapshots` | `/.snapshots` | snapshots are outside `@`, so a rollback does not delete them |
| `@var_log` | `/var/log` | logs survive a rollback (we keep the evidence of what broke) |
| `@pkg` | `/var/cache/pacman/pkg` | large, re-downloadable; not worth snapshotting |
| `@swap` | `/swap` | swapfiles cannot live in a snapshotted subvolume |

- Mount options `noatime,compress=zstd:1,space_cache=v2` (see `/etc/fstab`), and only `subvol=` (no `subvolid=`) so rollbacks keep booting.
- **Automatic snapshots** with snapper: `scripts/tema03-setup-snapper.sh` (also run by `install.sh`, stage `snapper`).
  - timeline: `snapper-timeline.timer` takes an hourly snapshot, and `snapper-cleanup.timer` keeps 5 hourly + 7 daily;
  - pacman: the `snap-pac` ALPM hook takes a *pre* and a *post* snapshot around every pacman transaction.
- **Rollback demo**: `scripts/tema03-rollback-demo.sh`.
- **Benchmark**: `scripts/tema03-fio-bench.sh` + `scripts/fio-summary.py`.

### Advantages and disadvantages of btrfs (justification)
| | btrfs | ext4 |
|---|---|---|
| Snapshots | instant and cheap (copy-on-write: only new blocks are written) | none (needs LVM) |
| Checksums | data and metadata (detects silent corruption); metadata stored twice (`DUP`) | metadata journaling only |
| Compression | transparent (`zstd`) | no |
| Subvolumes | yes, share the free space of the pool | no |
| Random writes | slower: CoW rewrites blocks elsewhere and updates the metadata tree (fragmentation) | in place, usually faster |
| Maturity / tools | `fsck` cannot repair everything; RAID5/6 still not recommended | very mature |

## 2. Operating-systems concept
File-system implementation: allocation methods, copy-on-write and journaling, free-space management, consistency and recovery.
Silberschatz, Galvin & Gagne, *Operating System Concepts* 10th ed., ch. 14 (File-System Implementation, §14.7 Recovery) and ch. 15 (File-System Internals).

## 3. Measurement method
**Benchmark (btrfs vs ext4):**
```bash
./scripts/tema03-fio-bench.sh
```
- btrfs: our real root (`/var/tmp/fio-btrfs`, `compress=zstd:1`).
- ext4: a 3 GiB loop image on the same virtual disk, created with `chattr +C` (no CoW underneath).
- fio, `--direct=1` (bypasses the page cache), `--ioengine=io_uring --iodepth=16`, 1 GiB file, 20 s per run, **3 runs** per workload:
  - sequential read/write, 1 MiB blocks;
  - random read/write, 4 KiB blocks.
- Raw JSON: `docs/evidence/tema-03/fio/`. Table: `docs/evidence/tema-03/fio/results.md`.

**Snapshots and rollback:**
```bash
./scripts/tema03-setup-snapper.sh      # once
sudo snapper -c root list               # timeline + pacman pre/post snapshots
./scripts/tema03-rollback-demo.sh       # live demo, saved to docs/evidence/tema-03/rollback-demo.txt
```

## 4. Results
Measured on `neonarch-hernan` (kernel 7.2.15, VirtualBox VDI on the host's NVMe SSD), 2026-11-10. fio `--direct=1 --ioengine=io_uring --iodepth=16`, 1 GiB file, 20 s per run, 3 runs. Raw JSON: `docs/evidence/tema-03/fio/`; ext4 loop device with `DIO 1` (`setup-ext4.txt`).

| Workload | btrfs (zstd:1, CoW) | ext4 (loop, direct I/O) | ext4 / btrfs |
|---|---|---|---|
| Sequential read, 1 MiB | 1825.6 ± 28.4 MiB/s · 8.75 ms | 1943.9 ± 15.1 MiB/s · 8.21 ms | 1.06× |
| Sequential write, 1 MiB | 165.4 ± 34.7 MiB/s · 100.0 ms | 634.8 ± 77.5 MiB/s · 25.4 ms | **3.8×** |
| Random read, 4 KiB | 104.2 ± 6.2 MiB/s · 26 683 IOPS · 575 µs | 105.9 ± 4.9 MiB/s · 27 111 IOPS · 583 µs | 1.02× |
| Random write, 4 KiB | 27.2 ± 0.1 MiB/s · 6 955 IOPS · 2.29 ms | 86.3 ± 4.1 MiB/s · 22 101 IOPS · 0.72 ms | **3.2×** |

(latency = mean completion latency reported by fio)

**Discarded first run:** with a *buffered* loop device the ext4 results were 5785 MiB/s and 217 914 random-read IOPS (71 µs), i.e. the page cache, not the disk. They are kept in `fio/discarded-buffered-loop/` and explained in `docs/bitacora_ia.md` (entry 7).

**Snapshots and rollback** (`docs/evidence/tema-03/rollback-demo.txt`, 2026-11-11):
- `snapper -c root list` shows snapshot #1 (baseline), hourly timeline snapshots, `single` snapshots taken with our shortcut **Super+Shift+S** (#17, #19), and a **pre/post pair for every pacman transaction** created by `snap-pac`.
- Demo `scripts/tema03-rollback-demo.sh`:

| Step | Command | Result |
|---|---|---|
| 1. initial state | `pacman -Q htop`, `htop --version` | `htop 3.5.3-1` installed and working |
| 2. destructive change | `sudo pacman -Rns htop` | snap-pac took **#22 (pre)** and **#23 (post)** automatically; our hook also logged the transaction |
| 3. it is gone | `pacman -Q htop`, `ls -l /usr/bin/htop` | `error: package 'htop' was not found`, `No such file or directory` |
| 4. what changed | `snapper status 22..23` | `-` (deleted): `/usr/bin/htop`, man page, icons, `.desktop`, **and pacman's database entry** `/var/lib/pacman/local/htop-3.5.3-1/{desc,files,mtree}`; `c` (changed): icon cache, ldconfig cache |
| 4. rollback | `snapper undochange 22..23` | `create:9 modify:2 delete:0` (≈ 0.1 s) |
| 5. verification | `pacman -Q htop`, `htop --version`, `pacman -Qkk htop` | installed and working again; `16 total files, 5 altered files`, all only *Modification time mismatch* |

## 5. Interpretation
- **Reads are equivalent** (within 2–6 %, inside the run-to-run variation). Reading does not modify anything, so copy-on-write costs nothing; the extra btrfs work (verifying the crc32c checksum of every block) is cheap compared with the I/O itself.
- **Writes are 3–4× slower on btrfs.** This is the price of copy-on-write. Every write goes to a **new** location: btrfs allocates a new extent, writes the data, computes and stores its checksum in the checksum tree, and updates the extent tree and the file's B-tree up to the root. Metadata is `DUP` (written twice), so one small user write becomes several metadata writes. Small random writes suffer the most (2.29 ms vs 0.72 ms per I/O). ext4 overwrites the blocks **in place** and journals only metadata.
- **Controlled comparison inside the same disk:** the ext4 image itself lives on the btrfs root but was created with `chattr +C` (**NOCOW**). Data that bypasses CoW writes 3–4× faster on the same device and the same btrfs filesystem. This isolates CoW (plus checksums) as the cause.
- **Sequential write variance is high on btrfs** (±34.7 MiB/s). A likely contributor is that the mount has `compress=zstd:1`: btrfs first tries to compress, finds the data incompressible (fio fills buffers with random data) and falls back to uncompressed extents, and direct I/O on a compression-enabled file can be turned into buffered I/O. This makes the timing less regular.
- **Why we still chose btrfs:** for a desktop OS the dominant pattern is reading, where btrfs matches ext4, while CoW gives us what ext4 cannot: instant snapshots before every pacman upgrade (`snap-pac`), rollback in seconds, checksums that detect silent corruption, and transparent compression for normal (compressible) files. Workloads that are dominated by random writes (databases, VM images, swapfiles) should use NOCOW files or subvolumes, which is exactly what we did with `@swap`.
- **Rollback:** the snapshot is the state of `@` just before the pacman transaction. `snapper status` diffs two snapshots by walking the btrfs trees, and `undochange` copies back what changed. It also restored **pacman's own database** (`/var/lib/pacman/local/htop-*`), so pacman "remembers" htop again: the system is consistent, not just the binary. This works because `/var/lib/pacman` lives inside `@`, while `/var/log` (`@var_log`) and the package cache (`@pkg`) are separate subvolumes that a rollback does not touch, so the logs of what happened survive.
- **What `pacman -Qkk` revealed:** after the rollback, 5 files differ from pacman's MTREE **only in modification time**; size, permissions and checksums match. `undochange` is a *file-level* restore: it creates the files again with the current time. For an exact, whole-system rollback, snapper offers `snapper rollback`, which makes a writable copy of the snapshot and sets it as the default subvolume (atomic, but it needs a reboot and a layout where `/` is mounted by default subvolume). Our `fstab` uses `subvol=/@` (no `subvolid`) precisely so that a renamed/replaced `@` keeps booting (see `docs/instalacion.md`, step 7).
- **Demo pitfall found:** the first version of the demo printed `/usr/bin/htop` for `command -v htop` *after* the removal, because bash caches command paths (hash table). Fixed with `hash -r` (AI log, entry 8).
- **Limitations:** a VM on a VDI file (the host OS cache and SSD are underneath), 3 runs of 20 s, one file size; absolute numbers are not those of real hardware, but the relative comparison on the same virtual disk is valid.
