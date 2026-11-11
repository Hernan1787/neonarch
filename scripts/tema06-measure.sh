#!/usr/bin/env bash
# =============================================================================
# Topic 6 — pacman: internals, own hook and own package (evidence)
#  1. pacman configuration: local database, sync databases, signature policy
#  2. build our package neonarch-tools with makepkg and install it with pacman -U
#     (our hook 95-neonarch-report.hook runs at the end of the transaction)
#  3. inspect it: pacman -Qi / -Ql / -Qo / -Qk
#  4. dependency resolution: pactree, and what pacman would install (-Sp) without installing
#  5. trigger the hook again by installing and removing a small package (figlet)
# Output: docs/evidence/tema-06/
# =============================================================================
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/docs/evidence/tema-06"; mkdir -p "$OUT"
save() { local f="$1"; shift; { echo "\$ $*"; eval "$*" 2>&1; } | tee "$OUT/$f"; echo; }
sudo -v

echo "=== 1. pacman internals ==="
save config.txt          "pacman --version | head -3; grep -E '^(SigLevel|LocalFileSigLevel|Architecture|ParallelDownloads)' /etc/pacman.conf; grep -E '^\[' /etc/pacman.conf"
save database.txt        "echo 'local db entries:' \$(ls /var/lib/pacman/local | wc -l); ls /var/lib/pacman/local | head -3; ls /var/lib/pacman/local/\$(ls /var/lib/pacman/local | grep '^bash-' | head -1); du -sh /var/lib/pacman/local /var/lib/pacman/sync; ls -l /var/lib/pacman/sync"
save keyring.txt         "sudo pacman-key --list-keys 2>/dev/null | grep -c '^pub' | xargs echo 'trusted public keys:'; sudo pacman-key --list-sigs archlinux 2>/dev/null | head -5"

echo "=== 2. Build and install neonarch-tools ==="
cd "$REPO_DIR/pacman/pkgbuild/neonarch-tools" || exit 1
save makepkg.txt         "makepkg -f --noconfirm"
PKG=$(ls -t ./neonarch-tools-*.pkg.tar.zst | head -1)
save install.txt         "sudo pacman -U --noconfirm $PKG"
cd "$REPO_DIR" || exit 1

echo "=== 3. Our package as pacman sees it ==="
save qi.txt              "pacman -Qi neonarch-tools"
save ql.txt              "pacman -Ql neonarch-tools"
save qo.txt              "pacman -Qo /usr/bin/neon-info"
save qk.txt              "pacman -Qkk neonarch-tools"
save pkg-contents.txt    "tar -tvf pacman/pkgbuild/neonarch-tools/$PKG"

echo "=== 4. Dependency resolution ==="
save pactree-i3.txt      "pactree -d 2 i3-wm"
save pactree-reverse.txt "pactree -r -d 1 python"
save sp-resolution.txt   "pacman -Sp --print-format '%n %v' xfce4-terminal"

echo "=== 5. Hook in action ==="
save hook-install.txt    "sudo pacman -S --noconfirm figlet"
save hook-remove.txt     "sudo pacman -Rns --noconfirm figlet"
save hook-log.txt        "tail -n 5 /var/log/neonarch/pacman.log"
echo "Evidence saved in docs/evidence/tema-06/"
