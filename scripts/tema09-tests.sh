#!/usr/bin/env bash
# =============================================================================
# Topic 9 — evidence: positive AND negative tests (denials are the evidence)
# Output: docs/evidence/tema-09/
# The nmap scan must be run FROM ANOTHER MACHINE (see docs/tema-09-seguridad.md).
# =============================================================================
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/docs/evidence/tema-09"; mkdir -p "$OUT"
t() { local f="$1"; shift; { echo "\$ $*"; eval "$*" 2>&1; echo "(exit status $?)"; echo; } | tee -a "$OUT/$f"; }
rm -f "$OUT"/*.txt
sudo -v

echo "### users, groups, permissions and ACLs" | tee "$OUT/acl.txt"
t acl.txt "id operator; id guest"
t acl.txt "ls -ld /srv/neonlab; getfacl /srv/neonlab"
t acl.txt "sudo -u operator sh -c 'echo report > /srv/neonlab/op.txt' && ls -l /srv/neonlab/op.txt"
t acl.txt "getfacl /srv/neonlab/op.txt                 # inherited from the default ACL"
t acl.txt "sudo -u guest cat /srv/neonlab/op.txt        # read allowed"
t acl.txt "sudo -u guest sh -c 'echo hack > /srv/neonlab/guest.txt'   # EXPECTED: Permission denied"
t acl.txt "sudo -u guest rm /srv/neonlab/op.txt          # EXPECTED: Permission denied"
t acl.txt "sudo -u nobody ls /srv/neonlab               # EXPECTED: Permission denied (others ---)"

echo "### restricted sudo" | tee "$OUT/sudo.txt"
t sudo.txt "sudo -l -U operator"
t sudo.txt "sudo -l -U guest"
t sudo.txt "sudo -l -U operator /usr/bin/systemctl restart neon-health.service   # allowed: prints the command"
t sudo.txt "sudo -l -U operator /usr/bin/pacman -Syu        # EXPECTED: not allowed (exit status 1)"
t sudo.txt "sudo -l -U operator /usr/bin/bash               # EXPECTED: not allowed (no root shell)"
t sudo.txt "sudo -l -U guest                                # EXPECTED: guest may not run sudo"
t sudo.txt "sudo journalctl _COMM=sudo --since '-10min' --no-pager | tail -n 8   # the denials are logged"

echo "### firewall" | tee "$OUT/firewall.txt"
t firewall.txt "sudo nft list ruleset"
t firewall.txt "ss -tlnp | head -20     # listening sockets"
t firewall.txt "sudo journalctl -k --grep nft-drop --since '-1h' --no-pager | tail -n 10"

echo "### ssh" | tee "$OUT/ssh.txt"
t ssh.txt "sudo sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowgroups|maxauthtries|x11forwarding)'"
t ssh.txt "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o PreferredAuthentications=password localhost true   # EXPECTED: Permission denied (publickey)"
echo "Evidence in docs/evidence/tema-09/. Now run the nmap scan from the other machine."
