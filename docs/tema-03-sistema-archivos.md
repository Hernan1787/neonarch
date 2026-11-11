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
<!-- Paste docs/evidence/tema-03/fio/results.md here and the relevant lines of rollback-demo.txt -->

## 5. Interpretation
<!-- To be written with the real data. Points to discuss:
- Sequential: does btrfs match ext4? (large blocks, few metadata updates)
- Random 4 KiB writes: btrfs is expected to be slower because of copy-on-write
  (each small write allocates a new block and updates the B-tree, plus checksums).
- Reads: both should be close; differences come from extent layout and checksums.
- Limitations: VM on a VDI file over the host SSD (host cache), 3 runs only.
- Snapshot cost: creating a snapshot is instant (metadata only); space grows only as files change. -->
