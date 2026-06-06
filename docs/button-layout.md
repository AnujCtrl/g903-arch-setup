# G903 button layout

The G903 LIGHTSPEED is marketed as 11 programmable buttons. `ratbagctl` exposes **12 button indices (0–11)**.

## Identifiers

| Layer | Value (on this hardware) |
|---|---|
| USB IDs | `046d:c539` (Lightspeed dongle), `046d:4087` (paired mouse) |
| `ratbagctl` device | random codename like `screaming-acouchy` — see `ratbagctl list` |
| evdev / makima device name | `Logitech G903 LS` |

The libratbag codename is stable across reboots but resets if you repair the mouse to the receiver. The evdev name is what makima TOML filenames use.

## Modular thumb buttons (the magnetic side caps)

The G903 is fully ambidextrous and uses a **magnetic snap-on system** for its 4 thumb buttons:

- **2 buttons on the left side** of the mouse (default thumb buttons for right-handed grip).
- **2 buttons on the right side** (default thumb buttons for left-handed grip; right-handers can install these as extra side buttons or leave them as blank covers).

Each side cap is either a 2-button module or a blank cover, and they snap on/off with magnets. The mouse ships with one button module and one blank module, plus the swap-in pieces in the box. Total physical thumb buttons available: **4** (when both modules are installed). Marketing calls the configuration "7 to 11 programmable buttons" — that range reflects whether side modules are installed.

Removing a side module doesn't reshuffle `ratbagctl` indices — the indices for the missing buttons just stop emitting events.

## Index → physical button

| Index | Physical button | Notes |
|---|---|---|
| 0 | Left click | primary |
| 1 | Right click | secondary |
| 2 | Middle click (scroll wheel press) | |
| 3 | Wheel-mode toggle / top-front button | toggles ratchet ↔ free-spin in hardware by default |
| 4 | **Left side — lower** thumb button | part of the left magnetic module |
| 5 | **Left side — upper** thumb button | part of the left magnetic module |
| 6 | **Right side — lower** thumb button | only emits when right cap module is installed |
| 7 | **Right side — upper** thumb button | only emits when right cap module is installed |
| 8 | DPI cycle (top of mouse, behind scroll) | |
| 9 | Scroll wheel tilt **left** | libratbag reports as `wheel-left` |
| 10 | Scroll wheel tilt **right** | libratbag reports as `wheel-right` |
| 11 | Profile cycle (underside / behind sensor) | defaults to `profile-cycle-up` |

Caveat: which physical position corresponds to "upper" vs "lower" inside each side module is best confirmed by pressing each button while running `evtest` or watching `journalctl -u makima -f`. If a binding feels backwards after testing, just swap the dispatcher arguments rather than re-flashing Piper.

## Verify physically

If you're unsure which physical button maps to which index, press one button while running:

```bash
ratbagctl <device> button 4 action get      # change 4 to each index
```

…or watch raw events from the evdev node:

```bash
sudo evtest /dev/input/eventN               # find N via 'cat /proc/bus/input/devices'
```

## Reading the current profile

```bash
ratbagctl <device> info
```

Sample output for an in-use profile:

```
Profile 0:
  Resolutions:
    0: 800dpi
    1: 850dpi (active) (default)
  Button: 0 is mapped to 'button 1'
  Button: 1 is mapped to 'button 2'
  ...
  Button: 9 is mapped to macro '↓KEY_LEFTCTRL ↕KEY_MINUS ↑KEY_LEFTCTRL'    # tilt-left → Ctrl+-
  Button: 10 is mapped to macro '↓KEY_LEFTCTRL ↕KEY_EQUAL ↑KEY_LEFTCTRL'   # tilt-right → Ctrl+=
  Button: 11 is mapped to 'profile-cycle-up'
```

## Quirks

- `ratbagd` sometimes needs a restart after unplug/repair to re-detect the mouse: `sudo systemctl restart ratbagd` (libratbag issue #1193).
- Piper's GUI dropdown is incomplete — no F13–F24, some media keys. Use `ratbagctl <device> button N action set macro KEY_F13` (or similar) for those.
- The G903 has 5 onboard profiles (0–4). `ratbagctl <device> profile N enable` activates one, `<device> button N` operates on the currently active profile unless you prefix `profile N`.
