# NeonArch — comandos propios y atajos de teclado

## Comandos propios (`bin/` → `~/.local/bin/`)

### `neonarch-health`
Diagnóstico integral. Comprueba: kernel vs módulos, zram cargado/activo,
swap, uso de btrfs en `/`, unidades systemd fallidas, snapshots, paquetes
huérfanos, actualizaciones pendientes, errores en journal, temperatura.

Salida con `[ok]`, `[info]`, `[warn]`, `[fail]`. Códigos: `0` OK, `1` warns,
`2` fails. Flags: `--help`, `--quiet`.

### `neonarch-clean`
Limpieza segura. Por defecto **dry-run**; `--yes` aplica. Acciones
seleccionables con `--pacman`, `--journal`, `--snapshots`, `--cache`,
`--orphans`, o `--all`. Muestra uso de btrfs antes/después.

Flags: `--help`, `--dry-run`, `--yes`, `--all`, y los individuales.

### `neonarch-calc`
Calculadora rápida en terminal. Usa `read -e` (readline) para que
`Backspace`, flechas y `Ctrl+U` funcionen. Evalúa expresiones con `python3`.
`q` para salir.

## Atajos de teclado (i3)

| Atajo | Acción |
|---|---|
| `$mod+Shift+l` | Bloquear pantalla (`i3lock -c 000000`) |
| `$mod+Shift+k` | Calculadora (`neonarch-calc` en `xterm`) |
| `$mod+Shift+p` | Captura con selección (`maim -s`) a `~/capturas/` |

> Nota: `$mod+Shift+c` está reservado por i3 para `reload`, por eso la
> calculadora usa `k`.

## Dependencias en `pkglist.txt`

- `i3lock` — bloqueo de pantalla.
- `maim` — captura con selección.
- `python` — calculadora.

## Instalación

`install.sh` enlaza `bin/*` a `~/.local/bin/` y copia `dotfiles/i3/config`
a `~/.config/i3/config`. Los paquetes se instalan desde `pkglist.txt`.

## Pruebas
neonarch-health
neonarch-clean # dry-run
neonarch-clean --journal --yes
neonarch-calc

En i3: `Super+Shift+L`, `Super+Shift+K`, `Super+Shift+P`.
