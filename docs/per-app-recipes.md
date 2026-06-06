# Writing per-application configs

makima loads one TOML per device, plus optional per-window-class overrides selected by filename.

## File naming

```
~/.config/makima/
├── Logitech G903 LS.toml                   # default (fallback)
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
# left = what the mouse sends; right = what makima emits instead.
# Combos use '-' INSIDE one string in the array.

BTN_SIDE = ["KEY_LEFTCTRL-KEY_W"]           # back thumb → Ctrl+W (close tab)
BTN_EXTRA = ["KEY_LEFTCTRL-KEY_T"]          # forward thumb → Ctrl+T (new tab)

# Sequences: array of multiple strings = multiple chord presses in order
BTN_FORWARD = ["KEY_LEFTCTRL-KEY_C", "KEY_LEFTCTRL-KEY_V"]   # copy then paste

[commands]
# Bind a button to a shell command (don't block on it).
BTN_BACK = ["notify-send", "back button pressed"]

[settings]
GRAB_DEVICE = "true"
```

## The `GRAB_DEVICE` setting

- `"false"` (default) — both the original event and the remapped event reach the focused app. Good for the fallback config when you want passthrough plus a few additions.
- `"true"` — makima grabs the device exclusively; only the remapped event reaches the app. Use in per-app files where you want a button to *only* do the new thing, not its original action.

For a per-app override that fully replaces button behavior, set `GRAB_DEVICE = "true"` in that file.

## Common evdev names

What the mouse sends (left side of remap rules):

| Name | Physical button on G903 |
|---|---|
| `BTN_LEFT` | left click |
| `BTN_RIGHT` | right click |
| `BTN_MIDDLE` | scroll wheel press |
| `BTN_SIDE` | side thumb back (typical default) |
| `BTN_EXTRA` | side thumb forward (typical default) |
| `BTN_FORWARD` | additional side button |
| `BTN_BACK` | additional side button |
| `REL_HWHEEL` | scroll wheel tilt (when sent as wheel) |

If you remapped a button in Piper to a keyboard key (e.g. `KEY_INSERT`), use that key name on the left side instead — makima sees whatever the mouse firmware emits.

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

1. Write the TOML.
2. Focus the target app.
3. Press the mapped button — observe the intended action.
4. Focus a different app — confirm the button reverts to default (or whatever its Piper-set base is).
5. Tail logs while testing: `journalctl -u makima -f`.

## Hyprland-specific tip

If a button doesn't trigger your per-app config, check what window class is actually focused:

```bash
hyprctl activewindow | grep class
```

Common gotcha: Electron apps and Steam games can report unexpected classes. Match exactly what shows up while the app is focused.
