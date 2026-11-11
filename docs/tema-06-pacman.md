# Topic 6: Package management (pacman)
**Owner:** Hernán Alonso Gutiérrez Quesada

## 1. What was implemented
| Item | File |
|---|---|
| Own ALPM hook: after every transaction it logs the packages to `/var/log/neonarch/pacman.log`, lists orphan packages, and warns if the kernel or systemd were upgraded while the old one is still running | `pacman/hooks/95-neonarch-report.hook` + `pacman/scripts/pacman-report` |
| Own package **`neonarch-tools`** (`neon-info`, `neon-ps`, `neon-boost`, `neon-net` → `/usr/bin`), built with `makepkg` | `pacman/pkgbuild/neonarch-tools/PKGBUILD` |
| Third-party hook used by Topic 3: `snap-pac` (btrfs snapshot before and after each transaction) | `pkglist.txt` |
| Deployment: `install.sh` copies the hook to `/etc/pacman.d/hooks/` and the script to `/usr/local/lib/neonarch/` | `install.sh` (stage `system`) |

### How pacman works (summary for the defence)
- **Databases:** the *sync* databases (`/var/lib/pacman/sync/core.db`, `extra.db`) are downloaded with `-Sy` and list every package in the repositories. The *local* database (`/var/lib/pacman/local/<pkg>-<ver>/{desc,files,mtree}`) records what is installed, why (explicit or dependency) and which files belong to each package.
- **Dependency resolution:** for `-S X`, pacman reads `depends=` from the sync db, builds the dependency graph, adds the missing packages, checks file conflicts against the local db, and only then downloads.
- **Signatures:** `SigLevel = Required DatabaseOptional` (`/etc/pacman.conf`): every package must carry a valid PGP signature from a key in the pacman keyring (`archlinux-keyring`, `pacman-key`), so a modified mirror cannot inject packages.
- **Hooks (`alpm-hooks(5)`):** `.hook` files with `[Trigger]` (operation, type, target) and `[Action]` (`When=PreTransaction|PostTransaction`, `Exec=`, `NeedsTargets`).
- **makepkg:** runs `package()` in a fakeroot, writes `.PKGINFO` and `.MTREE`, and compresses everything into `.pkg.tar.zst`, which `pacman -U` installs and registers in the local db like any repository package.

## 2. Operating-systems concept
OS services and system programs (installation, update, integrity), and protection: signed packages.
Silberschatz et al., *Operating System Concepts* 10th ed., ch. 2 (OS structures, system programs, linkers/loaders, §2.8 building and booting), ch. 16 (Security: authentication, code signing); Arch manual pages `pacman(8)`, `alpm-hooks(5)`, `PKGBUILD(5)`, `makepkg(8)`.

## 3. Measurement method
```bash
./install.sh                   # deploys the hook
./scripts/tema06-measure.sh    # builds/installs the package, triggers the hook, collects evidence
```
The script saves (in `docs/evidence/tema-06/`): pacman configuration and signature policy, local database layout, `makepkg` output, the `pacman -U` transaction **showing our hook running**, `pacman -Qi/-Ql/-Qo/-Qkk neonarch-tools`, the package contents (`tar -tvf`), `pactree -d 2 i3-wm`, `pactree -r python`, the packages pacman *would* install for `xfce4-terminal` (`-Sp`, resolution without installing), and the hook firing on install and remove of `figlet` plus the log file.

## 4. Results
<!-- key lines: hook output in install.txt / hook-install.txt, pacman -Qi neonarch-tools, pactree -->

## 5. Interpretation
<!-- What the hook proves (PostTransaction, NeedsTargets on stdin); why packaging our commands is
better than copying them (pacman tracks the files: -Qo, -Qk, clean removal with -R); what the
dependency tree shows. -->
