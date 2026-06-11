# Writing per-application configs

makima loads one TOML per device, plus optional per-window-class overrides selected by filename. Use makima when you want different button behavior in different applications.

## When to use makima vs. Hyprland directly

| Goal | Tool |
|---|---|
| Same behavior in every app (workspace switching, focus movement, global shortcut) | **Hyprland binds** — see [defaults.md](defaults.md). makima not needed. |
| Different behavior per app (Firefox close-tab on thumb, terminal copy on thumb) | **makima** — keep reading. |

`apply-defaults.sh` **masks** the makima service (`systemctl mask`) so a pacman hook, Omarchy update, or stray `systemctl start` can't quietly reintroduce it — which would silently re-enable the echo-doubling behavior. **To bring makima back for per-app TOMLs you have to unmask it first:**

```bash
sudo systemctl unmask makima
sudo systemctl enable --now makima
journalctl -u makima -f                   # tail to confirm it picks up your TOMLs
```

The `mask` choice is deliberate. `disable` alone wasn't durable — the service kept getting silently re-enabled (likely by a pacman post-install hook on a `makima-bin` update), reintroducing the workspace-jumps-by-2 bug after a reboot. `mask` symlinks the unit to `/dev/null` so only an explicit `unmask` brings it back.

## The echo gotcha

makima always creates a virtual keyboard device that re-emits events from devices it monitors. With **GRAB_DEVICE = "false"** and an empty or trivial `[remap]`, Hyprland sees every keypress **twice**: once from the real G903's kernel-keyboard interface, and once from makima's virtual echo. This shows up as "workspace jumps by 2" or "focus jumps two windows at once."

Two ways to avoid this:

1. **Don't run makima** when there are no per-app TOMLs that need it. The `apply-defaults.sh` script does this for you.
2. **Use `GRAB_DEVICE = "true"` in every active TOML** — makima grabs the device exclusively, so the real-keyboard events don't reach apps; only what makima emits does. Your per-app TOMLs in `examples/` follow this pattern.

Note: if you turn on makima for per-app overrides and have an empty `~/.config/makima/Logitech G903 LS.toml` (the fallback file) sitting there with `GRAB_DEVICE = "false"`, you'll re-introduce the double for windows that *don't* match a per-app file. Either delete the global file or use the "explicit identity remap" pattern below.

### Explicit identity remap (safe global fallback)

If you want makima always running but no remap for unmatched windows, write the global file with `GRAB_DEVICE = "true"` and an explicit identity remap for every key you care about:

```toml
[remap]
KEY_F13 = ["KEY_F13"]
KEY_F14 = ["KEY_F14"]
KEY_F15 = ["KEY_F15"]
KEY_F16 = ["KEY_F16"]

[settings]
GRAB_DEVICE = "true"
```

This intercepts the F-keys and re-emits them once each, so each press still triggers Hyprland's bind exactly once. It's verbose but eliminates the double.

## File naming

```
~/.config/makima/
├── Logitech G903 LS.toml                   # default fallback (see above for trade-off)
├── Logitech G903 LS::firefox.toml          # active only when Firefox is focused
├── Logitech G903 LS::Alacritty.toml        # active only when Alacritty is focused
└── Logitech G903 LS::code.toml             # active only when VS Code is focused
```

Format: `<evdev_device_name>::<window_class>.toml`. The literal `::` is the delimiter.

## Finding a window class

On Hyprland, with the target application open and focused:

```bash
hyprctl clients | grep -A4 -i <app-keyword>
```

Look at the `class:` field. Examples:

| App | Typical `class` |
|---|---|
| Firefox | `firefox` |
| Chrome | `Google-chrome` |
| Alacritty | `Alacritty` |
| Kitty | `kitty` |
| VS Code | `code` or `Code` |
| Discord | `discord` |
| Spotify | `Spotify` |
| OBS | `com.obsproject.Studio` |

Class match is case-sensitive — match exactly what `hyprctl` prints.

## Anatomy of a TOML

```toml
[remap]
# left = what the mouse sends; right = an array of one or more chord strings.
# Combos use '-' INSIDE one string.

KEY_F13 = ["KEY_LEFTCTRL-KEY_W"]            # bottom-left thumb → Ctrl+W (close tab)
KEY_F14 = ["KEY_LEFTCTRL-KEY_T"]            # top-left thumb → Ctrl+T (new tab)

# Sequences: array of multiple chord strings = multiple chord presses in order
KEY_F15 = ["KEY_LEFTCTRL-KEY_C", "KEY_LEFTCTRL-KEY_V"]   # copy then paste

[commands]
# Bind a key to a shell command (don't block on it).
KEY_F16 = ["notify-send", "right top button pressed"]

[settings]
GRAB_DEVICE = "true"
```

Note: the left side of `[remap]` matches the keycode the mouse firmware emits. Since this repo's default has Piper sending `KEY_F13`–`KEY_F16` for the thumb buttons, the per-app TOMLs use those names — not `BTN_SIDE` / `BTN_EXTRA`.

## The `GRAB_DEVICE` setting

- `"true"` — makima grabs the device exclusively; **only** the remapped event reaches the app. Use this in per-app files so the original `KEY_F13` doesn't fire alongside the remap.
- `"false"` — both the original event and the remapped event reach the focused app. **Causes the echo double on Wayland** when used with the G903 (see above). Avoid unless you really want both events.

## Common keys to emit (right side)

| Modifier | Letter | Function | Nav |
|---|---|---|---|
| `KEY_LEFTCTRL` | `KEY_A` … `KEY_Z` | `KEY_F1` … `KEY_F12` | `KEY_HOME`, `KEY_END` |
| `KEY_LEFTSHIFT` | `KEY_0` … `KEY_9` | `KEY_F13` … `KEY_F24` | `KEY_PAGEUP`, `KEY_PAGEDOWN` |
| `KEY_LEFTALT` | | `KEY_INSERT`, `KEY_DELETE` | `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT` |
| `KEY_LEFTMETA` | | `KEY_ESC`, `KEY_TAB`, `KEY_ENTER`, `KEY_SPACE` | |

Numpad: `KEY_KP0` … `KEY_KP9`, `KEY_KPPLUS`, `KEY_KPMINUS`, `KEY_KPENTER`, `KEY_KPDOT`.

## After editing

makima reloads its configs when files change (inotify). If you want to be explicit:

```bash
sudo systemctl restart makima
journalctl -u makima -f       # confirm new config picked up
```

## Sanity checking a new config

1. Make sure makima is running: `systemctl is-active makima` should say `active`.
2. Write the TOML.
3. Focus the target app.
4. Press the mapped button — observe the intended action.
5. Focus a different app — confirm the button reverts to default (or whatever your other TOML says).
6. Tail logs while testing: `journalctl -u makima -f`.

## Hyprland-specific tip

If a button doesn't trigger your per-app config, check what window class is actually focused:

```bash
hyprctl activewindow | grep class
```

Common gotcha: Electron apps and Steam games can report unexpected classes. Match exactly what shows up while the app is focused.
