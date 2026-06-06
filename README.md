# g903-arch-setup

Per-application button mapping for the Logitech G903 LIGHTSPEED on Arch Linux. Replaces what G HUB would do on Windows/macOS using only open-source tools:

- **[Piper](https://github.com/libratbag/piper) + [libratbag](https://github.com/libratbag/libratbag)** — write button macros, DPI, polling rate, LEDs to the mouse's onboard memory.
- **[makima](https://github.com/cyber-sushi/makima)** — userspace daemon that swaps active remap rules based on the focused window class (Hyprland / Sway / Niri / X11). **Optional** — only needed when you actually want different behavior per application.

## Quick start

```bash
git clone https://github.com/AnujCtrl/g903-arch-setup.git
cd g903-arch-setup
./scripts/install.sh                      # packages + systemd drop-in
./scripts/apply-defaults.sh               # optional: thumb buttons -> workspace/focus
```

`install.sh`:

1. Installs `piper`, `libratbag`, `makima-bin` via `pacman`.
2. Drops a fixed `makima.service` override into `/etc/systemd/system/makima.service.d/`.
3. Enables and starts `ratbagd`. **Leaves makima stopped** — it only needs to run for per-app overrides.
4. Copies `examples/*.toml` into `~/.config/makima/` if that directory is empty.

`apply-defaults.sh` (optional, Hyprland-specific):

1. Activates profile 0 and writes `KEY_F13`–`KEY_F16` to **thumb buttons 3, 4, 5, 6** on every enabled onboard profile (verified positions via `evtest`).
2. Resets wheel-tilt buttons (9, 10) to native horizontal scroll.
3. Installs `hyprland/g903.conf` and wires `source =` into `~/.config/hypr/hyprland.conf`.
4. Binds workspace prev/next on the **left** side, `movefocus l/r` on the **right** side.
5. Enables `cursor:warp_on_change_workspace` so the pointer follows focus.
6. Ensures the makima service is stopped (global defaults don't need it).

See [docs/defaults.md](docs/defaults.md) for the full mapping and how to flip/revert. Launch `piper` after install if you want the GUI for DPI / LEDs / extra macros.

## Architecture

```
                       ┌───────────────────────────┐
                       │  Global defaults (this    │
                       │  repo's apply-defaults)   │
                       │                           │
Mouse button press     │   no makima needed        │
       │               │                           │
       ▼               │                           │
G903 firmware ─────────┴─► Linux evdev /dev/input/eventN
   (Piper-set                       │
    onboard profile                 │
    emits KEY_F13…F16)              ▼
                              Hyprland binds
                                    │
                                    ▼
                              Focused application


                       ┌───────────────────────────┐
                       │  Per-app overrides        │
                       │  (optional, opt-in)       │
                       │                           │
Mouse button press     │   makima enabled          │
       │               │                           │
       ▼               │                           │
G903 firmware ─────────┴─► Linux evdev ──► makima daemon
                                              │  reads focused window class
                                              │  loads "Logitech G903 LS::<class>.toml"
                                              │  emits remapped event via /dev/uinput
                                              ▼
                                          Hyprland binds → Focused app
```

The shipped default keeps things minimal: mouse firmware emits unique F-keys, Hyprland binds them. makima only enters the picture when you want per-application behavior — at which point its `GRAB_DEVICE = "true"` per-app TOMLs replace the global default for that window.

## Repo layout

| Path | Purpose |
|---|---|
| `scripts/install.sh` | Idempotent base setup (packages + service + makima config dir) |
| `scripts/apply-defaults.sh` | Apply the workspace/focus defaults to mouse + Hyprland |
| `systemd/makima-override.conf` | systemd drop-in fixing the upstream unit's empty `User=` and `/home//` placeholder |
| `hyprland/g903.conf` | Hyprland snippet: thumb-button binds + cursor warp on workspace switch |
| `examples/Logitech G903 LS.toml` | Global passthrough makima config (only used if makima is enabled) |
| `examples/Logitech G903 LS::firefox.toml` | Example per-app override (Firefox) |
| `examples/Logitech G903 LS::Alacritty.toml` | Example per-app override (terminal) |
| `docs/button-layout.md` | Verified physical → `ratbagctl` index table |
| `docs/defaults.md` | What `apply-defaults.sh` does and how to verify / flip / revert |
| `docs/per-app-recipes.md` | How to enable makima + write your own `::window_class.toml` files |
| `docs/diagnostics.md` | `evtest`-based debugging methodology (what determined the verified mapping) |
| `docs/games.md` | Old games (Minecraft / LWJGL 2) caveats and workarounds |

## Verification

After install:

```bash
ratbagctl list                              # should print the G903 with a libratbag codename
systemctl is-active ratbagd                 # should say "active"
systemctl is-active makima                  # "inactive" is expected for global-only setups
ls ~/.config/makima/                        # at least the example TOMLs should be present
```

After `apply-defaults.sh`:

```bash
# Each thumb press should produce exactly ONE workspace/focus action.
# To see raw mouse events bypassing every layer:
sudo pacman -S evtest
grep -B1 -A4 "Logitech G903" /proc/bus/input/devices    # find event node
evtest /dev/input/eventN                                 # press buttons, watch KEY_F13..F16
```

See [docs/diagnostics.md](docs/diagnostics.md) for the full debugging primer.

## License

MIT — see [LICENSE](LICENSE).
