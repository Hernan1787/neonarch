#!/usr/bin/env bash
# =============================================================================
# Topic 7 — extra systemd-boot entries for the live demo (idempotent)
#   NeonArch (rescue)    -> systemd.unit=rescue.target    (single-user, base system + fs mounted)
#   NeonArch (emergency) -> systemd.unit=emergency.target (only / mounted read-only, nothing else)
# Both ask for the ROOT password (sulogin). At boot, hold SPACE to see the menu.
# =============================================================================
set -euo pipefail
sudo -v
UUID=$(findmnt -no UUID /)
for t in rescue emergency; do
    f=/boot/loader/entries/neonarch-$t.conf
    content="title   NeonArch ($t.target)
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$UUID rootflags=subvol=@ rw systemd.unit=$t.target"
    if [[ "$(sudo cat "$f" 2>/dev/null)" == "$content" ]]; then
        echo "[ok]      $f"
    else
        printf '%s\n' "$content" | sudo tee "$f" >/dev/null
        echo "[changed] $f"
    fi
done
sudo bootctl list --no-pager | grep -E 'title|id:' 
