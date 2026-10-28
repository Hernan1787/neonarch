#!/usr/bin/env bash
# Collects the Layer 1 installation evidence required by assignment A.3:
#   lsblk -f, /etc/fstab, bootctl status / efibootmgr -v, journalctl --list-boots
# Output: docs/evidence/install/<hostname>/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$(cat /etc/hostname 2>/dev/null || uname -n)"
OUT="$REPO_DIR/docs/evidence/install/$HOST"
mkdir -p "$OUT"

run() {   # run <file> <command...>  -> saves "$ command" + output
    local file="$1"; shift
    {
        echo "\$ $*"
        echo "# collected $(date --iso-8601=seconds) on $HOST by $USER"
        "$@" 2>&1 || echo "(command exited with status $?)"
    } > "$OUT/$file"
    echo "  saved $file"
}

echo "Collecting installation evidence into $OUT"
run lsblk-f.txt              lsblk -f
run fstab.txt                cat /etc/fstab
run bootctl-status.txt       sudo bootctl status
run efibootmgr.txt           efibootmgr -v
run journalctl-list-boots.txt journalctl --list-boots --no-pager
run btrfs-subvolumes.txt     sudo btrfs subvolume list /
run findmnt-root.txt         findmnt -no SOURCE,FSTYPE,OPTIONS /
run uname.txt                uname -a
run firmware-mode.txt        cat /sys/firmware/efi/fw_platform_size
run loader-entries.txt       sudo sh -c 'for f in /boot/loader/loader.conf /boot/loader/entries/*.conf; do echo "== $f"; cat "$f"; done'
run mkinitcpio-hooks.txt     grep -E '^(HOOKS|MODULES)=' /etc/mkinitcpio.conf
echo "Done. Review the files and commit them:"
echo "  git add docs/evidence/install/$HOST && git commit -m \"docs: install evidence for $HOST\""
