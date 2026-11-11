#!/usr/bin/env bash
# =============================================================================
# Topic 3 — fio benchmark: btrfs (our root, zstd:1, CoW) vs ext4 (loop image)
# Workloads: sequential read/write 1 MiB blocks, random read/write 4 KiB blocks
# O_DIRECT (--direct=1) bypasses the page cache so we measure the filesystem
# and the disk, not RAM. 3 runs of 20 s per workload and filesystem (~9 min).
# The ext4 image lives on the btrfs root but with CoW disabled (chattr +C), so
# btrfs adds no copy-on-write of its own underneath ext4.
# Output: docs/evidence/tema-03/fio/*.json + results.md
# =============================================================================
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/docs/evidence/tema-03/fio"; mkdir -p "$OUT"
SIZE=${SIZE:-1G}; RUNTIME=${RUNTIME:-20}; RUNS=${RUNS:-3}
BTRFS_DIR=/var/tmp/fio-btrfs
IMG=/var/tmp/fio-ext4.img
EXT4_DIR=/mnt/fio-ext4

sudo -v
sudo mkdir -p "$BTRFS_DIR" && sudo chown "$USER" "$BTRFS_DIR"
if ! mountpoint -q "$EXT4_DIR"; then
    sudo rm -f "$IMG"
    sudo touch "$IMG" && sudo chattr +C "$IMG"     # NOCOW must be set while the file is empty
    sudo fallocate -l 3G "$IMG"
    sudo mkfs.ext4 -q -F "$IMG"
    sudo mkdir -p "$EXT4_DIR"
    sudo mount -o loop "$IMG" "$EXT4_DIR"
    sudo chown "$USER" "$EXT4_DIR"
fi
{ findmnt -no TARGET,FSTYPE,OPTIONS /; findmnt -no TARGET,FSTYPE,OPTIONS "$EXT4_DIR"; lsattr "$IMG"; } | tee "$OUT/setup.txt"

declare -A RW=( [seqread]=read [seqwrite]=write [randread]=randread [randwrite]=randwrite )
declare -A BS=( [seqread]=1M   [seqwrite]=1M    [randread]=4k       [randwrite]=4k )
for fs in btrfs ext4; do
    dir=$BTRFS_DIR; [[ $fs == ext4 ]] && dir=$EXT4_DIR
    for job in seqread seqwrite randread randwrite; do
        for run in $(seq 1 "$RUNS"); do
            echo ">> $fs $job run $run"
            fio --name="$job" --directory="$dir" --size="$SIZE" --runtime="$RUNTIME" --time_based \
                --direct=1 --ioengine=io_uring --iodepth=16 --numjobs=1 \
                --rw="${RW[$job]}" --bs="${BS[$job]}" --group_reporting \
                --output-format=json --output="$OUT/$fs-$job-$run.json"
            rm -f "$dir/$job".*      # remove the test file between runs
        done
    done
done
python3 "$REPO_DIR/scripts/fio-summary.py" "$OUT" | tee "$OUT/results.md"
sudo umount "$EXT4_DIR" && sudo rm -f "$IMG"
