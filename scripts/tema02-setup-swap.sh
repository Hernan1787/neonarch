#!/usr/bin/env bash
# =============================================================================
# Topic 2 — disk swapfile on the @swap btrfs subvolume (idempotent)
# A swapfile on btrfs must be NOCOW and not compressed; "btrfs filesystem mkswapfile"
# creates it correctly. zram (config/zram-generator.conf) is enabled by install.sh.
# =============================================================================
set -euo pipefail
SWAP=/swap/swapfile
if [[ -f $SWAP ]]; then
    echo "[ok]      $SWAP exists"
else
    sudo btrfs filesystem mkswapfile --size 2g "$SWAP"
    echo "[changed] created $SWAP (2 GiB)"
fi
if ! grep -q "^$SWAP" /etc/fstab; then
    echo "$SWAP none swap defaults,pri=10 0 0" | sudo tee -a /etc/fstab >/dev/null
    echo "[changed] added $SWAP to /etc/fstab (priority 10)"
fi
sudo swapon -a
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
swapon --show
zramctl
