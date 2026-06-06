# g903-arch-setup

Per-application button mapping for the Logitech G903 LIGHTSPEED on Arch Linux. Replaces what G HUB would do on Windows/macOS using only open-source tools:

- **[Piper](https://github.com/libratbag/piper) + [libratbag](https://github.com/libratbag/libratbag)** — write button macros, DPI, polling rate, LEDs to the mouse's onboard memory.
- **[makima](https://github.com/cyber-sushi/makima)** — userspace daemon that swaps active remap rules based on the focused window class (Hyprland / Sway / Niri / X11).

## Quick start

```bash
git clone https://github.com/AnujCtrl/g903-arch-setup.git
cd g903-arch-setup
./scripts/install.sh
./scripts/apply-defaults.sh    # optional: thumb buttons -> workspace/focus on Hyprland
```

`install.sh`:

1. Installs `piper`, `libratbag`, `makima-bin` via `pacman`.
2. Drops a fixed `makima.service` override into `/etc/systemd/system/makima.service.d/`.
3. Enables and starts `ratbagd` and `makima`.
4. Copies `examples/*.toml` into `~/.config/makima/` if that directory is empty.

`apply-defaults.sh` (optional, Hyprland-specific):

1. Reassigns thumb buttons 4–7 to `F13`–`F16` on the mouse.
2. Installs `hyprland/g903.conf` and wires `source =` into `~/.config/hypr/hyprland.conf`.
3. Binds workspace prev/next on the **left** side, `movefocus l/r` on the **right** side.
4. Enables `cursor:warp_on_change_workspace` so the pointer follows focus.

See [docs/defaults.md](docs/defaults.md) for what gets set and how to flip/revert. Launch `piper` after install if you want the GUI for DPI / LEDs / extra macros.

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
| `scripts/install.sh` | Idempotent base setup (packages + service + makima config dir) |
| `scripts/apply-defaults.sh` | Optional: apply the shipped workspace/focus defaults to mouse + Hyprland |
| `systemd/makima-override.conf` | systemd drop-in fixing the upstream unit's empty `User=` and `/home//` placeholder |
| `hyprland/g903.conf` | Hyprland snippet: F13–F16 binds + cursor warp on workspace switch |
| `examples/Logitech G903 LS.toml` | Default passthrough makima config |
| `examples/Logitech G903 LS::firefox.toml` | Example per-app override (Firefox) |
| `examples/Logitech G903 LS::Alacritty.toml` | Example per-app override (terminal) |
| `docs/button-layout.md` | Physical → `ratbagctl` index table + modular thumb-button anatomy |
| `docs/defaults.md` | What `apply-defaults.sh` does and how to verify / flip / revert |
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
