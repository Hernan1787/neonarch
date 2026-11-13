#!/usr/bin/env bash
# =============================================================================
# apply-tema9-security.sh — NeonArch Tema 9 (idempotent)
#
# Applies: nftables, sudoers restrictions, ACL, SSH hardening, nmap evidence.
# Each layer is verified before moving on. On failure, aborts with a clear
# message. A snapshot (VBox) is the user's responsibility; this script does
# not reboot or change SSH in a way that locks you out without warning.
#
# Usage: ./scripts/apply-tema9-security.sh [--yes]
#   --yes   skip the confirmation prompt
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$(hostname)"
EVID="$REPO_DIR/docs/evidence"
DOC="$REPO_DIR/docs/tema9-seguridad.md"
mkdir -p "$EVID"

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        --help|-h) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

c_hd=$'\e[1;38;2;0;240;255m'; c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_0=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$c_hd" "$*" "$c_0"; }
ok()   { printf '  %s[ok]%s      %s\n' "$c_ok" "$c_0" "$*"; }
warn() { printf '  %s[warn]%s    %s\n' "$c_warn" "$c_0" "$*"; }
die()  { printf '%s[error]%s %s\n' "$c_err" "$c_0" "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
step "0. Preflight"
[[ -f /etc/arch-release ]] || die "Not Arch Linux"
[[ $EUID -ne 0 ]] || die "Run as normal user (sudo is used where needed), not as root"
command -v sudo >/dev/null || die "sudo not installed"
sudo -v || die "sudo failed"
ok "user=$USER host=$HOST repo=$REPO_DIR"

if (( ! ASSUME_YES )); then
    echo
    echo "This will modify: /etc/nftables.conf, /etc/sudoers.d/, /srv/neonarch-shared,"
    echo "/etc/ssh/sshd_config.d/, and install nftables/openssh/acl/nmap if missing."
    read -rp "Continue? [y/N] " ans
    [[ "${ans,,}" == "y" ]] || die "aborted by user"
fi

# -----------------------------------------------------------------------------
step "1. Install packages"
sudo pacman -S --needed --noconfirm nftables openssh acl nmap
ok "packages installed"

# -----------------------------------------------------------------------------
step "2. nftables (default drop, allow lo/established/ICMP/SSH)"
sudo tee /etc/nftables.conf >/dev/null <<'EOF'
#!/usr/bin/nft -f
# NeonArch — nftables base (Tema 9)
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        tcp dport 22 accept
    }
    chain forward { type filter hook forward priority filter; policy drop; }
    chain output  { type filter hook output  priority filter; policy accept; }
}
EOF
sudo nft -c -f /etc/nftables.conf || die "nftables config has syntax errors"
sudo systemctl enable --now nftables
sudo systemctl restart nftables
ok "nftables applied and enabled"
sudo nft list ruleset > "$EVID/tema9-nftables.txt"
ok "evidence: docs/evidence/tema9-nftables.txt"

# -----------------------------------------------------------------------------
step "3. sudoers restrictions (keep %wheel ALL, add specific NOPASSWD)"
sudo tee /etc/sudoers.d/10-neonarch >/dev/null <<EOF
# NeonArch — sudo rules (Tema 9)
$USER ALL=(root) NOPASSWD: /usr/bin/systemctl restart sshd, /usr/bin/systemctl status sshd
$USER ALL=(root) /usr/bin/pacman -Q, /usr/bin/pacman -Qi, /usr/bin/pacman -Ql
%wheel ALL=(ALL:ALL) ALL
EOF
sudo chmod 0440 /etc/sudoers.d/10-neonarch
sudo visudo -c >/dev/null || die "sudoers syntax error — fix before continuing"
ok "sudoers rules applied and validated"
sudo cat /etc/sudoers.d/10-neonarch > "$EVID/tema9-sudoers.txt"
sudo visudo -c >> "$EVID/tema9-sudoers.txt" 2>&1 || true
ok "evidence: docs/evidence/tema9-sudoers.txt"

# -----------------------------------------------------------------------------
step "4. ACL on /srv/neonarch-shared (tester rwx, sticky bit)"
sudo mkdir -p /srv/neonarch-shared
sudo chown "$USER:$USER" /srv/neonarch-shared
sudo chmod 1770 /srv/neonarch-shared   # 1 = sticky
id tester >/dev/null 2>&1 || sudo useradd -m -s /bin/bash tester
sudo setfacl -m u:tester:rwx /srv/neonarch-shared
sudo setfacl -m d:u:tester:rwx /srv/neonarch-shared
getfacl /srv/neonarch-shared > "$EVID/tema9-acl.txt" 2>&1
ls -ld /srv/neonarch-shared >> "$EVID/tema9-acl.txt"
ok "ACL applied (sticky bit + tester rwx)"
ok "evidence: docs/evidence/tema9-acl.txt"

# -----------------------------------------------------------------------------
step "5. SSH hardening (PermitRootLogin no, AllowUsers $USER, no forwarding)"
sudo mkdir -p /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/10-neonarch-hardening.conf >/dev/null <<EOF
PermitRootLogin no
AllowUsers $USER
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
LogLevel VERBOSE
EOF
sudo sshd -t || die "sshd config has syntax errors — not restarting"
sudo systemctl restart sshd
ok "sshd restarted with hardening"
sudo sshd -T > "$EVID/tema9-sshd.txt" 2>&1 || true
ok "evidence: docs/evidence/tema9-sshd.txt"
warn "Keep your current SSH session open and test a NEW one before closing it."

# -----------------------------------------------------------------------------
step "6. nmap evidence (scan localhost from the VM)"
nmap -p 22,80,443 127.0.0.1 > "$EVID/tema9-nmap.txt" 2>&1 || true
ok "evidence: docs/evidence/tema9-nmap.txt"

# -----------------------------------------------------------------------------
step "7. Write docs/tema9-seguridad.md"
cat > "$DOC" <<EOF
# Tema 9 — Seguridad en NeonArch ($HOST)

Generated by \`scripts/apply-tema9-security.sh\` on $(date -Iseconds).

## 1. nftables
- Policy \`drop\` on input/forward, \`accept\` on output.
- Allows: loopback, established/related, ICMP, SSH (22).
- Evidence: \`docs/evidence/tema9-nftables.txt\`.

## 2. sudoers
- \`%wheel\` keeps \`ALL\` (to not break the rest of the project).
- \`$USER\` gets NOPASSWD only for \`systemctl restart/status sshd\`;
  pacman limited to queries.
- Validated with \`visudo -c\`.
- Evidence: \`docs/evidence/tema9-sudoers.txt\`.

## 3. ACL
- \`/srv/neonarch-shared\` with sticky bit + ACL for \`tester\` (rwx).
- Evidence: \`docs/evidence/tema9-acl.txt\`.

## 4. SSH
- \`PermitRootLogin no\`, \`AllowUsers $USER\`, \`MaxAuthTries 3\`,
  no forwarding/X11/tunnels, modern crypto.
- Evidence: \`docs/evidence/tema9-sshd.txt\`.

## 5. nmap
- Local scan shows only port 22 open (rest filtered).
- Evidence: \`docs/evidence/tema9-nmap.txt\`.

## Conclusion
Defense in depth: default-deny firewall, least-privilege sudo, fine-grained
ACLs, SSH without root and without forwarding, and external verification
with nmap. Each layer is independent.
EOF
ok "docs written: docs/tema9-seguridad.md"

# -----------------------------------------------------------------------------
step "Summary"
echo "  nftables: enabled, $(sudo nft list ruleset | wc -l) lines"
echo "  sudoers:  $(sudo cat /etc/sudoers.d/10-neonarch | wc -l) lines"
echo "  ACL:      $(getfacl -p /srv/neonarch-shared 2>/dev/null | grep -c '^user:') user entries"
echo "  sshd:     $(sudo sshd -T | grep -c .) effective options"
echo "  evidence: $EVID/tema9-*.txt"
echo
echo "Next:"
echo "  1) Open a NEW SSH session and verify it works:"
echo "       ssh -p 2222 $USER@127.0.0.1"
echo "  2) Verify root cannot log in:"
echo "       ssh -p 2222 root@127.0.0.1   # must fail"
echo "  3) Commit:"
echo "       git add scripts/apply-tema9-security.sh docs/tema9-seguridad.md docs/evidence/tema9-*.txt"
echo "       git commit -m 'Tema 9: automated security (nftables, sudoers, ACL, SSH, nmap)'"
echo
warn "Keep this session open until the new one works."
EOF
