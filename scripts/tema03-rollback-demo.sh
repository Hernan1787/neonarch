#!/usr/bin/env bash
# =============================================================================
# Topic 3 — LIVE DEMO: destructive change -> rollback from a btrfs snapshot
# 1. htop is installed and works
# 2. we remove it with pacman; snap-pac takes a PRE and a POST snapshot
# 3. htop is gone
# 4. snapper undochange PRE..POST copies the files back from the PRE snapshot
#    (binary, man pages AND pacman's database in /var/lib/pacman)
# 5. htop works again and pacman lists it as installed
# Output is also saved to docs/evidence/tema-03/rollback-demo.txt
# =============================================================================
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/docs/evidence/tema-03"; mkdir -p "$OUT"
exec > >(tee "$OUT/rollback-demo.txt") 2>&1
pause() { echo; read -rp "   [Enter] para continuar..." _ </dev/tty; }
run()   { printf '\n\e[1;35m$ %s\e[0m\n' "$*"; eval "$*"; }

sudo -v
echo "=== 1. Estado inicial ==="
run "pacman -Q htop"
run "command -v htop && htop --version"
pause
echo "=== 2. Cambio destructivo: desinstalar htop (snap-pac crea snapshots pre/post) ==="
run "sudo pacman -Rns --noconfirm htop"
run "sudo snapper -c root list | tail -n 3"
pause
echo "=== 3. htop ya no existe ==="
run "pacman -Q htop"
run "command -v htop || echo 'htop: not found'"
pause
POST=$(sudo snapper --csvout -c root list --columns number,type | awk -F, '$2=="post"{n=$1} END{print n}')
PRE=$(sudo snapper --csvout -c root list --columns number,type,pre-number | awk -F, -v p="$POST" '$1==p{print $3}')
echo "=== 4. Rollback de los archivos: snapshot PRE=$PRE -> POST=$POST ==="
run "sudo snapper -c root status $PRE..$POST | head -n 15"
run "sudo snapper -c root undochange $PRE..$POST"
pause
echo "=== 5. Verificación ==="
run "pacman -Q htop"
run "command -v htop && htop --version"
echo; echo "Demo guardada en docs/evidence/tema-03/rollback-demo.txt"
