#!/usr/bin/env bash
# =============================================================================
# Topic 9 — protection and security setup (idempotent)
#  users/groups : "operator" (restricted sudo) and "guest" (no sudo), group "neonlab"
#  shared dir   : /srv/neonlab  owner root:neonlab, 2770 (setgid) + ACLs:
#                 operator rwx, guest r-x, default ACLs so new files inherit them
#  sudoers      : security/sudoers.d/60-neonarch-operator (validated with visudo)
#  firewall     : security/nftables.conf (default drop) -> /etc/nftables.conf
#  ssh          : security/ssh/50-neonarch.conf -> /etc/ssh/sshd_config.d/
# =============================================================================
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sudo -v
getent group neonlab >/dev/null || sudo groupadd neonlab
for u in operator guest; do
    id "$u" >/dev/null 2>&1 || { sudo useradd -m -s /bin/bash "$u"; echo "created user $u (set a password with: sudo passwd $u)"; }
done
sudo usermod -aG neonlab operator
sudo usermod -aG neonlab "$USER"

sudo mkdir -p /srv/neonlab
sudo chown root:neonlab /srv/neonlab
sudo chmod 2770 /srv/neonlab                     # rwx for group, setgid: new files get group neonlab
sudo setfacl -m u:operator:rwx,u:guest:rx /srv/neonlab
sudo setfacl -d -m u:operator:rwx,u:guest:rx,g:neonlab:rwx,o::--- /srv/neonlab

tmp=$(mktemp); sudo install -m 440 -o root -g root "$REPO_DIR/security/sudoers.d/60-neonarch-operator" "$tmp"
sudo visudo -cf "$tmp" && sudo install -m 440 -o root -g root "$tmp" /etc/sudoers.d/60-neonarch-operator; sudo rm -f "$tmp"

sudo nft -c -f "$REPO_DIR/security/nftables.conf"          # syntax check first
sudo install -m 644 "$REPO_DIR/security/nftables.conf" /etc/nftables.conf
sudo systemctl enable --now nftables.service
sudo systemctl restart nftables.service

sudo install -D -m 644 "$REPO_DIR/security/ssh/50-neonarch.conf" /etc/ssh/sshd_config.d/50-neonarch.conf
sudo sshd -t
sudo systemctl enable --now sshd.service
sudo systemctl restart sshd.service
echo "Topic 9 configuration applied."
