# g903-arch-setup

Per-application button mapping for the Logitech G903 LIGHTSPEED on Arch Linux. Replaces what G HUB would do on Windows/macOS using only open-source tools:

- **[Piper](https://github.com/libratbag/piper) + [libratbag](https://github.com/libratbag/libratbag)** — write button macros, DPI, polling rate, LEDs to the mouse's onboard memory.
- **[makima](https://github.com/cyber-sushi/makima)** — userspace daemon that swaps active remap rules based on the focused window class (Hyprland / Sway / Niri / X11).

## Quick start

```bash
git clone https://github.com/AnujCtrl/g903-arch-setup.git
cd g903-arch-setup
./scripts/install.sh
```

The script:

1. Installs `piper`, `libratbag`, `makima-bin` via `pacman`.
2. Drops a fixed `makima.service` override into `/etc/systemd/system/makima.service.d/`.
3. Enables and starts `ratbagd` and `makima`.
4. Copies `examples/*.toml` into `~/.config/makima/` if that directory is empty.

Then launch `piper` once to configure the mouse's onboard memory.

## Architecture

```
Mouse button press
    │
    ▼
G903 firmware (Piper-configured onboard profile)
    │  emits BTN_SIDE / KEY_INSERT / etc.
    ▼
Linux evdev → /dev/input/eventN
    │
    ▼
makima daemon (reads focused window class from compositor)
    │  loads "Logitech G903 LS::<window_class>.toml"
    │  falls back to "Logitech G903 LS.toml"
    ▼
Re-emits via /dev/uinput
    │
    ▼
Focused application
```

Why two layers: the mouse firmware has no idea what window is focused, and the compositor has no idea what HID buttons your mouse has. Piper owns the hardware layer, makima owns the per-app layer.

## Repo layout

| Path | Purpose |
|---|---|
| `scripts/install.sh` | Idempotent setup for a fresh Arch box |
| `systemd/makima-override.conf` | systemd drop-in fixing the upstream unit's empty `User=` and `/home//` placeholder |
| `examples/Logitech G903 LS.toml` | Default passthrough config |
| `examples/Logitech G903 LS::firefox.toml` | Example per-app override (Firefox) |
| `examples/Logitech G903 LS::Alacritty.toml` | Example per-app override (terminal) |
| `docs/button-layout.md` | Physical → `ratbagctl` index table |
| `docs/per-app-recipes.md` | How to write your own `::window_class.toml` files |
| `docs/games.md` | Old games (Minecraft / LWJGL 2) caveats and workarounds |

## Verification

After install:

```bash
ratbagctl list                              # should print the G903 with a libratbag codename
systemctl is-active ratbagd makima          # both should say "active"
ls ~/.config/makima/                        # at least the default TOML should be present
journalctl -u makima -f                     # watch live events as you press buttons
```

## License

MIT — see [LICENSE](LICENSE).
