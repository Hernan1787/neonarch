# Tema 9 — Seguridad en NeonArch

## 1. nftables
- Política `drop` por defecto en input/forward, `accept` en output.
- Permite: loopback, established/related, ICMP, SSH (22).
- Evidencia: `docs/evidence/tema9-nftables.txt`.

## 2. sudoers restringido
- `%wheel` conserva ALL (para no romper el resto del proyecto).
- Reglas específicas para `roy`: NOPASSWD solo para `systemctl restart/status sshd`; pacman solo consultas.
- Validado con `visudo -c`.
- Evidencia: `docs/evidence/tema9-sudoers.txt`.

## 3. ACL
- `/srv/neonarch-shared` con ACL para `tester` (rwx) y sticky bit (`+t`) para impedir borrado.
- Evidencia: `docs/evidence/tema9-acl.txt`.

## 4. SSH endurecido
- `PermitRootLogin no`, `AllowUsers roy`, `MaxAuthTries 3`, sin forwarding/X11/túneles, criptografía moderna.
- Clave ed25519 obligatoria (password deshabilitado tras verificar).
- Evidencia: `docs/evidence/tema9-sshd.txt`.

## 5. nmap
- Scan desde el host a la VM: solo puerto 22 visible; el resto filtrado por nftables.
- Evidencia: `docs/evidence/tema9-nmap.txt`.

## Conclusión
El sistema aplica defensa en profundidad: firewall por defecto deny, sudo de mínimo privilegio, ACL para permisos finos, SSH sin root y sin password, y verificación externa con nmap. Cada capa es independiente: si una falla, las otras siguen protegiendo.
