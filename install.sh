#!/usr/bin/env bash
# =============================================================================
#  NeonArch — bootstrap script (Layer 1, reproducibility)
#
#  Turns a clean manual Arch install into NeonArch:
#    1. packages   install pkglist.txt (+ VM guest tools)          [pacman]
#    2. dotfiles   symlink dotfiles/ into $HOME                     [ln -s]
#    3. commands   symlink bin/* into ~/.local/bin                  [ln -s]
#    4. system     copy units, hooks, udev rules, configs to /etc   [install]
#    5. services   enable units listed in config/services.txt      [systemctl]
#
#  IDEMPOTENT: every step first checks the current state and only acts when
#  something differs. Running it twice changes nothing the second time
#  (the summary at the end reports "0 changes").
#
#  Usage:  ./install.sh                 # all stages
#          ./install.sh dotfiles system # only some stages
#  Log:    logs/install-<hostname>-<timestamp>.log  (commit it as evidence)
# =============================================================================
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="$(cat /etc/hostname 2>/dev/null || uname -n)"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/install-$HOST-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

CHANGES=0
RELOAD_SYSTEMD=0
RELOAD_UDEV=0

c_ok=$'\e[32m'; c_chg=$'\e[33m'; c_err=$'\e[31m'; c_hd=$'\e[1;38;2;0;240;255m'; c_0=$'\e[0m'
step()    { printf '\n%s==> %s%s\n' "$c_hd" "$*" "$c_0"; }
ok()      { printf '  %s[ok]%s      %s\n' "$c_ok" "$c_0" "$*"; }
changed() { printf '  %s[changed]%s %s\n' "$c_chg" "$c_0" "$*"; CHANGES=$((CHANGES + 1)); }
die()     { printf '%s[error]%s %s\n' "$c_err" "$c_0" "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
preflight() {
    step "Preflight"
    [[ -f /etc/arch-release ]] || die "This is not Arch Linux."
    [[ $EUID -ne 0 ]] || die "Run as your normal user (sudo is used where needed), not as root."
    command -v sudo >/dev/null || die "sudo is not installed."
    sudo -v || die "Your user cannot use sudo (is it in the wheel group?)."
    ok "Arch Linux, user=$USER, host=$HOST, repo=$REPO_DIR"
    ok "log file: ${LOG#"$REPO_DIR"/}"
}

# -----------------------------------------------------------------------------
# 1. Packages
# -----------------------------------------------------------------------------
read_list() {   # strip comments and blank lines from a list file
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1" | awk '{print $1}'
}

guest_packages() {
    case "$(systemd-detect-virt 2>/dev/null || true)" in
        oracle)    echo virtualbox-guest-utils ;;
        kvm|qemu)  echo qemu-guest-agent spice-vdagent ;;
        vmware)    echo open-vm-tools xf86-video-vmware ;;
        *)         ;;
    esac
}

stage_packages() {
    step "Packages (pkglist.txt)"
    local -a wanted missing
    mapfile -t wanted < <(read_list "$REPO_DIR/pkglist.txt"; guest_packages | tr ' ' '\n')
    # pacman -T prints only the dependencies that are NOT satisfied -> idempotency check
    mapfile -t missing < <(pacman -T "${wanted[@]}" || true)
    if ((${#missing[@]} == 0)); then
        ok "all ${#wanted[@]} packages already installed"
        return
    fi
    echo "  missing: ${missing[*]}"
    sudo pacman -Syu --needed --noconfirm "${missing[@]}"
    changed "installed ${#missing[@]} package(s)"
}

# -----------------------------------------------------------------------------
# 2/3. Symlinks (dotfiles and commands)
# -----------------------------------------------------------------------------
link() {   # link <source relative to repo> <absolute destination>
    local src="$REPO_DIR/$1" dst="$2"
    [[ -e $src ]] || die "missing source $1"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        ok "$dst"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -e $dst || -L $dst ]]; then
        mv "$dst" "$dst.bak-$(date +%Y%m%d%H%M%S)"
        echo "  backed up existing $dst"
    fi
    ln -s "$src" "$dst"
    changed "$dst -> $1"
}

stage_dotfiles() {
    step "Dotfiles"
    link dotfiles/bash/bashrc            "$HOME/.bashrc"
    link dotfiles/bash/bash_profile      "$HOME/.bash_profile"
    link dotfiles/x11/xinitrc            "$HOME/.xinitrc"
    link dotfiles/i3/config              "$HOME/.config/i3/config"
    link dotfiles/i3status/config        "$HOME/.config/i3status/config"
    link dotfiles/x11/Xresources         "$HOME/.Xresources"
    link dotfiles/rofi/config.rasi       "$HOME/.config/rofi/config.rasi"
    link dotfiles/dunst/dunstrc          "$HOME/.config/dunst/dunstrc"
}

stage_commands() {
    step "Own commands (bin/ -> ~/.local/bin)"
    local f
    for f in "$REPO_DIR"/bin/*; do
        [[ -f $f ]] || continue
        [[ -x $f ]] || { chmod +x "$f"; changed "chmod +x bin/${f##*/}"; }
        link "bin/${f##*/}" "$HOME/.local/bin/${f##*/}"
    done
}

# -----------------------------------------------------------------------------
# 4. System files (root-owned copies, not symlinks: /etc must not depend on $HOME)
# -----------------------------------------------------------------------------
deploy() {   # deploy <source relative to repo> <absolute destination> [mode]
    local src="$REPO_DIR/$1" dst="$2" mode="${3:-644}"
    if sudo test -f "$dst" && sudo cmp -s "$src" "$dst"; then
        ok "$dst"
        return 1
    fi
    sudo install -D -m "$mode" -o root -g root "$src" "$dst"
    changed "$dst"
    return 0
}

stage_system() {
    step "System files"
    local f
    for f in "$REPO_DIR"/systemd/system/*.{service,timer,socket,slice,path}; do
        deploy "systemd/system/${f##*/}" "/etc/systemd/system/${f##*/}" && RELOAD_SYSTEMD=1
    done
    for f in "$REPO_DIR"/systemd/system/*.d/*.conf; do   # drop-ins, e.g. foo.service.d/limits.conf
        local rel="${f#"$REPO_DIR"/}"
        deploy "$rel" "/etc/${rel}" && RELOAD_SYSTEMD=1
    done
    for f in "$REPO_DIR"/pacman/hooks/*.hook; do
        deploy "pacman/hooks/${f##*/}" "/etc/pacman.d/hooks/${f##*/}" || true
    done
    for f in "$REPO_DIR"/udev/*.rules; do
        deploy "udev/${f##*/}" "/etc/udev/rules.d/${f##*/}" && RELOAD_UDEV=1
    done
    for f in "$REPO_DIR"/config/sysctl.d/*.conf; do
        deploy "config/sysctl.d/${f##*/}" "/etc/sysctl.d/${f##*/}" && sudo sysctl --system >/dev/null
    done
    if [[ -f $REPO_DIR/config/zram-generator.conf ]]; then
        deploy config/zram-generator.conf /etc/systemd/zram-generator.conf && RELOAD_SYSTEMD=1
    fi
    for f in "$REPO_DIR"/systemd/scripts/*; do          # helper scripts executed by our units
        deploy "systemd/scripts/${f##*/}" "/usr/local/lib/neonarch/${f##*/}" 755 || true
    done

    if ((RELOAD_SYSTEMD)); then sudo systemctl daemon-reload; changed "systemctl daemon-reload"; fi
    if ((RELOAD_UDEV)); then sudo udevadm control --reload; changed "udevadm control --reload"; fi
}

# -----------------------------------------------------------------------------
# 5. Services
# -----------------------------------------------------------------------------
stage_services() {
    step "Services (config/services.txt)"
    local scope unit
    while read -r scope unit; do
        [[ -z ${scope:-} || $scope == \#* ]] && continue
        if [[ $scope == system ]]; then
            if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
                ok "$unit enabled"
            else
                sudo systemctl enable --now "$unit"
                changed "enabled $unit"
            fi
        elif [[ $scope == user ]]; then
            if systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then
                ok "$unit (user) enabled"
            else
                systemctl --user enable --now "$unit"
                changed "enabled $unit (user)"
            fi
        fi
    done < <(sed 's/#.*//' "$REPO_DIR/config/services.txt")
}

# -----------------------------------------------------------------------------
main() {
    local -a stages=("$@")
    ((${#stages[@]})) || stages=(packages dotfiles commands system services)
    preflight
    local s
    for s in "${stages[@]}"; do
        declare -F "stage_$s" >/dev/null || die "unknown stage '$s'"
        "stage_$s"
    done
    step "Summary"
    if ((CHANGES == 0)); then
        ok "system already up to date: 0 changes (idempotent run)"
    else
        printf '  %d change(s) applied. Run ./install.sh again: it should report 0 changes.\n' "$CHANGES"
    fi
    echo "  log: ${LOG#"$REPO_DIR"/}"
}

main "$@"
