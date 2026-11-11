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
Measured on `neonarch-hernan`, pacman **7.1.0** / libalpm 16.0.1, 2026-11-10. Raw output: `docs/evidence/tema-06/`.

**Configuration and databases** (`config.txt`, `database.txt`, `keyring.txt`)
- `SigLevel = Required DatabaseOptional`, `LocalFileSigLevel = Optional`, repositories `[core]` and `[extra]`, `ParallelDownloads = 5`.
- Local database: **416** installed packages, each one a directory `/var/lib/pacman/local/<name>-<version>/` with `desc`, `files`, `mtree` (and `install` when the package has a script); 12 MiB. Sync databases: `core.db` 128 KiB, `extra.db` 8.7 MiB.
- Keyring: **183** trusted public keys (`pacman-key --list-keys`).

**Our package** (`makepkg.txt`, `install.txt`, `qi.txt`, `ql.txt`, `qo.txt`, `qk.txt`, `pkg-contents.txt`)

| Check | Result |
|---|---|
| `makepkg -f` | fakeroot → strip/purge → `.PKGINFO`, `.BUILDINFO`, `.MTREE` → `neonarch-tools-1.0.0-2-any.pkg.tar.zst` |
| `pacman -Qi` | Version 1.0.0-2, Depends On `python`, 3 optional deps (all already installed), Installed Size 40.96 KiB, Install Reason *Explicitly installed*, Validated By *None* (local, unsigned) |
| `pacman -Ql` | 11 entries: `/usr/bin/neon-{boost,info,mem,net,ps}` and `/usr/share/doc/neonarch-tools/README.md` |
| `pacman -Qo /usr/bin/neon-info` | `is owned by neonarch-tools 1.0.0-2` |
| `pacman -Qkk` | `11 total files, 0 altered files` (checked against the MTREE) |

**Our hook in real transactions** (`install.txt`, `hook-install.txt`, `hook-remove.txt`, `hook-log.txt`): in every transaction pacman ran the hooks in order: snap-pac **pre** snapshot → package changes → `(2/3) NeonArch: logging transaction, checking orphans and kernel version... logged to /var/log/neonarch/pacman.log (1 package(s) in this transaction)` → snap-pac **post** snapshot. Log lines:
```
2026-11-10T23:41:36-06:00  1 package(s): neonarch-tools  | orphans=0
2026-11-10T23:41:37-06:00  1 package(s): figlet  | orphans=0      (install)
2026-11-10T23:41:37-06:00  1 package(s): figlet  | orphans=0      (removal)
```

**Dependency resolution** (`pactree-i3.txt`, `pactree-reverse.txt`, `sp-resolution.txt`): `pactree -d 2 i3-wm` shows i3 → libev, libxkbcommon-x11, pango (→ cairo, fontconfig…), etc.; `pactree -r -d 1 python` lists the installed packages that need Python (apparmor, fio, gdb…, and our own package); `pacman -Sp xfce4-terminal` resolved **9** packages to download (libxfce4util, xfconf, libgtop, libxfce4ui, vte-common, vte3, gtk-layer-shell…) without installing anything.

**Problem found:** the first build packaged four **empty** commands, because the files had been emptied in the working tree by a terminal paste (`docs/instalacion.md`, problem #14). `pacman -Ql` alone did not reveal it, but `tar -tvf` of the package showed `0` bytes. We restored the files, bumped `pkgrel` to 2 and rebuilt; the evidence above is from the corrected package.

## 5. Interpretation
- **Why a package instead of copying files:** after `pacman -U`, pacman *owns* every file. It can tell which package a file belongs to (`-Qo`), verify that nothing was modified (`-Qkk` compares size, mode and checksums with the MTREE), upgrade it by bumping `pkgver`/`pkgrel`, and remove it cleanly with `-R`. A file copied by hand to `/usr/bin` is invisible to all of this.
- **Hooks are the extension point of the package manager.** Our hook is `When = PostTransaction` with `NeedsTargets`, so pacman passes the transaction's package names on stdin. The ordering we observed (pre-snapshot, changes, our hook, post-snapshot) comes from the hook file names (`95-neonarch-report.hook` sorts before snap-pac's post hook). This connects Topic 6 with Topic 3: every transaction is now **reversible** with `snapper undochange <pre>..<post>`.
- **Security:** packages from the repositories are verified against the 183 keys of the keyring (`SigLevel = Required`). Our local package shows *Validated By: None* because `LocalFileSigLevel = Optional` allows unsigned files installed with `-U`. In a real distribution we would sign it with our own key (`makepkg --sign`) and add that key to the keyring.
- **Dependency resolution** is a graph problem: `-Sp` shows that installing one terminal would pull 9 packages, which is exactly why we chose minimal components (i3, xterm) in Layer 1.
- **Lesson from the empty package:** verify the *artifact*, not only the metadata. `tar -tvf` revealed what `-Qi` and `-Ql` could not.
