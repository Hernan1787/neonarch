# Topic 9: Protection and security
**Owner:** Royner Baltodano Sánchez · **Support:** Hernán Alonso Gutiérrez Quesada

> Evidence sheet (Annex 2). Owner's notes: [`docs/tema9-seguridad.md`](tema9-seguridad.md); raw evidence: `docs/evidence/tema9-*.txt`. Measured on `neonarch-roy`, 2026-11-12.

## 1. What was implemented
| Layer | Configuration (evidence) |
|---|---|
| Firewall | nftables, `inet filter`: **input policy drop**, forward drop, output accept; allows loopback, `established,related`, ICMP/ICMPv6 and TCP 22; drops `invalid` (`tema9-nftables.txt`) |
| Least-privilege sudo | `roy` may run **without password only** `systemctl restart/status sshd`, and pacman only for queries (`-Q`, `-Qi`, `-Ql`); every other command through `wheel` asks for the password and is logged; all files validated with `visudo -c` (`tema9-sudoers.txt`) |
| ACLs | `/srv/neonarch-shared`: owner `roy` rwx, named user `tester` rwx, group and others none, **default ACLs** so new files inherit them (`tema9-acl.txt`) |
| SSH | effective config (`sshd -T`): `PermitRootLogin no`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PubkeyAuthentication yes` (ed25519 key), `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no` (`tema9-sshd.txt`) |
| Already in the distribution | `neon-health.service` sandbox (`DynamicUser`, `ProtectSystem=strict`, Topic 4); ESP mounted `fmask=0077` (only root reads the bootloader) |

## 2. Operating-systems concept
Protection (domains, access matrix, access-control lists, principle of least privilege) and security (user authentication, network threats, firewalls, defence in depth).
Silberschatz, Galvin & Gagne, *Operating System Concepts* 10th ed., ch. 16 (Security: §16.5 user authentication, §16.6 firewalling) and ch. 17 (Protection: §17.3 least privilege, §17.5 access matrix, §17.6 access lists).

## 3. Method
- `nft list ruleset`, `sudo -l`, `visudo -c`, `getfacl`, `sshd -T`: the configuration as the kernel and the daemons actually apply it.
- Negative tests: accesses that must be denied.
- External scan with `nmap` from another machine against the VM.

## 4. Results
- The ruleset, sudoers, ACLs and SSH configuration listed above are in force (evidence files).
- `tester` created `tester.txt` in the shared directory; the file got the inherited ACL (`-rw-rw----+`).
- ⚠️ **Pending:** the negative test of the ACL tried to delete `roy.txt`, a file that did not exist (`No such file or directory`), so it does not prove a denial yet. The directory listing (`drwxrwx---+`) shows **no sticky bit**, although the owner's notes mention one.
- ⚠️ **Pending:** `tema9-nmap.txt` is a scan of **scanme.nmap.org (45.33.32.156)**, Nmap's public test host, not of our VM. It must be repeated against the VM's address from another machine, once with nftables stopped and once running.

## 5. Interpretation
- **Defence in depth:** the firewall closes the network, SSH removes password guessing and root login, sudo limits what a compromised account can do, and ACLs restrict files beyond owner/group/other. Each layer still protects if another fails.
- **Default deny:** with `policy drop`, a port without a rule gives no answer at all, so nmap reports it as *filtered*, not *closed* (a closed port answers with a TCP RST).
- **Keys instead of passwords:** with `PasswordAuthentication no` a brute-force attack has nothing to guess; the private key never leaves the client.
- **Least privilege:** `roy` can restart one service without a password, and pacman without a password is limited to queries. Note: `roy` is still in `wheel`, which keeps `ALL` *with* password (kept so the rest of the project's scripts work), so the restriction covers what runs without authentication, not everything. A stricter version would remove `roy` from `wheel` (like the `operator` user prepared in `security/sudoers.d/60-neonarch-operator`). Every sudo attempt, allowed or denied, is recorded in the journal.
