# Topic 9: Protection and security
**Owner:** Royner Baltodano Sánchez · **Support:** Hernán Alonso Gutiérrez Quesada

## 1. What was implemented (`scripts/tema09-setup.sh`)
| Mechanism | Configuration | Principle |
|---|---|---|
| Users and groups | `operator` (restricted sudo), `guest` (no sudo), group `neonlab`; admin user in `wheel` | least privilege, separation of roles |
| Shared directory | `/srv/neonlab` `root:neonlab` mode **2770** (setgid) + ACLs: `operator` rwx, `guest` r-x, others none; **default ACLs** so new files inherit them | discretionary access control beyond owner/group/other |
| Restricted sudo | `security/sudoers.d/60-neonarch-operator`: `operator` may only restart / check `neon-health.service`; `50-neonarch-boost`: wheel may run only `/usr/bin/neon-boost` without a password | least privilege, accountability (sudo logs to the journal) |
| Firewall | `security/nftables.conf`: input policy **drop**; allow loopback, established/related, rate-limited ICMP and SSH (6 new connections/min); log and count everything else | default deny |
| SSH hardening | `security/ssh/50-neonarch.conf`: no root login, **keys only** (no passwords), only group `wheel`, 3 tries | reduce attack surface; no password guessing |
| Service sandboxing (Topic 4) | `neon-health.service`: `DynamicUser`, `ProtectSystem=strict`, `ProtectHome`, `NoNewPrivileges` | defence in depth |
| ESP permissions | `/boot` mounted `fmask=0077,dmask=0077` | only root reads the bootloader / random seed |

## 2. Operating-systems concept
Protection (domains, access matrix, access lists/ACLs, principle of least privilege) and security (authentication, network threats, firewalls).
Silberschatz et al., *Operating System Concepts* 10th ed., ch. 16 (Security: §16.5 user authentication, §16.6 firewalling) and ch. 17 (Protection: §17.3 principle of least privilege, §17.5 access matrix, §17.6 access lists, §17.8 role-based access control).

## 3. Measurement method
```bash
./scripts/tema09-setup.sh
./scripts/tema09-tests.sh       # positive and NEGATIVE tests -> docs/evidence/tema-09/
```
**Negative tests (the denials are the evidence):** `guest` cannot write or delete in `/srv/neonlab`, `nobody` cannot even list it, `operator` cannot run `pacman` or a shell through sudo, `guest` cannot use sudo, password SSH login is refused, and dropped packets appear in the kernel log (`nft-drop:`).

**External scan (from ANOTHER machine):** both VMs must be on the same network (VirtualBox: *Settings → Network → Adapter 2 → Host-only Adapter*, or both on the same *NAT Network*). From the other machine:
```bash
nmap -Pn -sS -p 1-1024 <IP of this VM>     # expected: only 22/tcp open, the rest filtered
nmap -Pn -sU --top-ports 20 <IP>           # UDP: open|filtered (dropped, no ICMP reply)
```
Run it once **without** the firewall (`sudo systemctl stop nftables`) and once **with** it, and save both outputs in `docs/evidence/tema-09/nmap-before.txt` / `nmap-after.txt`.

## 4. Results
<!-- key lines of acl.txt, sudo.txt, firewall.txt, ssh.txt and both nmap scans -->

## 5. Interpretation
<!-- closed vs filtered ports (RST vs no answer = default drop), why keys beat passwords,
why default ACLs matter for files created later, what the sudo log shows. -->
