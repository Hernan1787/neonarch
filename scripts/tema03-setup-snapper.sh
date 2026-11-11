#!/usr/bin/env bash
# =============================================================================
# Topic 3 — automatic btrfs snapshots with snapper (idempotent)
# Our layout mounts the @snapshots subvolume at /.snapshots. "snapper
# create-config /" wants to create /.snapshots itself as a NESTED subvolume
# inside @, which would be lost on rollback. Standard workaround (Arch Wiki,
# Snapper > Suggested filesystem layout): let snapper create its config, delete
# the nested subvolume and mount our top-level @snapshots there again.
# =============================================================================
set -euo pipefail
if sudo snapper -c root get-config >/dev/null 2>&1; then
    echo "[ok]      snapper config 'root' already exists"
else
    sudo umount /.snapshots
    sudo rmdir /.snapshots
    sudo snapper -c root create-config /
    sudo btrfs subvolume delete /.snapshots
    sudo mkdir /.snapshots
    sudo mount /.snapshots            # uses the @snapshots line of /etc/fstab
    sudo chmod 750 /.snapshots
    # Timeline policy: keep 5 hourly + 7 daily snapshots, max 20 numbered (pacman) ones
    sudo snapper -c root set-config \
        TIMELINE_CREATE=yes TIMELINE_CLEANUP=yes \
        TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=0 \
        TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
        NUMBER_CLEANUP=yes NUMBER_LIMIT=20 \
        ALLOW_GROUPS=wheel SYNC_ACL=yes
    sudo snapper -c root create --description "tema03: baseline after setup"
    echo "[changed] snapper config 'root' created"
fi
sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer >/dev/null
findmnt -no SOURCE,OPTIONS /.snapshots
sudo snapper -c root list
