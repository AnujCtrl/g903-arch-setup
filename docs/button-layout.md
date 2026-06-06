# G903 button layout

The G903 LIGHTSPEED is marketed as "7 to 11 programmable buttons." `ratbagctl` exposes **12 button indices (0–11)**, but not all correspond to a physical control — the mapping is hardware-dependent and was determined empirically here via `evtest`.

## Identifiers

| Layer | Value (on this hardware) |
|---|---|
| USB IDs | `046d:c539` (Lightspeed dongle), `046d:4087` (paired mouse) |
| `ratbagctl` device | random codename like `screaming-acouchy` — see `ratbagctl list` |
| evdev / makima device name | `Logitech G903 LS` |

The libratbag codename is stable across reboots but resets if you repair the mouse to the receiver. The evdev name is what makima TOML filenames use.

## Modular thumb buttons (the magnetic side caps)

The G903 is fully ambidextrous and uses a **magnetic snap-on system** for its side modules. Each module has **2 buttons** (upper + lower), and both sides accept a module.

- Marketing says "11 programmable buttons" when both modules are installed.
- The mouse ships with one button module and one blank cover.
- Snap-on/off with magnets; no tools needed.

Removing a side module doesn't reshuffle `ratbagctl` indices — the buttons just stop emitting events.

## Index → physical button (verified via evtest)

This table is **ground truth on this hardware**, confirmed by remapping each ratbagctl button slot to a unique `KEY_F*` and running `evtest /dev/input/eventN` while pressing each physical position:

| Index | Physical button | Verified emission |
|---|---|---|
| 0 | Left click | primary mouse button |
| 1 | Right click | secondary mouse button |
| 2 | Middle click (scroll wheel press) | |
| **3** | **Bottom-left thumb button** | emits assigned key (verified F17 → `KEY_F17` value 1/0) |
| **4** | **Top-left thumb button** | emits assigned key (verified F13 → `KEY_F13` value 1/0) |
| **5** | **Bottom-right thumb button** | emits assigned key (verified F14 → `KEY_F14` value 1/0) |
| **6** | **Top-right thumb button** | emits assigned key (verified F15 → `KEY_F15` value 1/0) |
| 7 | unknown — never observed firing | physical correspondence unclear on this unit |
| 8 | DPI cycle (top of mouse, behind scroll) | emits when pressed |
| 9 | Scroll wheel tilt **left** | libratbag default: `wheel-left` |
| 10 | Scroll wheel tilt **right** | libratbag default: `wheel-right` |
| 11 | Profile cycle (underside, near sensor) | libratbag default: `profile-cycle-up` |

### Important corrections from earlier assumptions

If you've seen older docs in this repo (or in the libratbag wiki) that claim buttons 4–7 are the four thumb buttons and button 3 is a "wheel-mode toggle" — that's **wrong for the G903**. We verified with `evtest` that button **3** is the bottom-left thumb. There's no separate "front-of-scroll" button on the G903 in the first place.

`btn7` never fired during any combination of physical-button presses we tried (thumb, top buttons, wheel tilts, DPI, profile). It exists as a programmable slot in firmware but has no corresponding switch on this unit — treat it as unusable.

## Verifying on your own G903

The non-destructive workflow: assign each slot a unique `KEY_F*` and watch raw events.

```bash
# 1. Get device codename
ratbagctl list

# 2. Assign unique F-keys to slots we care about
ratbagctl <device> button 3 action set macro KEY_F13
ratbagctl <device> button 4 action set macro KEY_F14
ratbagctl <device> button 5 action set macro KEY_F15
ratbagctl <device> button 6 action set macro KEY_F16
ratbagctl <device> button 7 action set macro KEY_F17
ratbagctl <device> button 8 action set macro KEY_F18

# 3. Find the mouse's event device
grep -B1 -A4 "Logitech G903" /proc/bus/input/devices

# 4. Stream raw events
sudo pacman -S evtest
evtest /dev/input/eventN          # N from step 3, e.g. event9
```

Press each physical button once and note which `KEY_F*` value 1/0 pair appears. That's your per-unit mapping. See [diagnostics.md](diagnostics.md) for the full debugging methodology this repo's defaults are based on.

## Reading the current profile

```bash
ratbagctl <device> info
```

Sample output for an in-use profile:

```
Profile 0: (active)
  Resolutions:
    0: 800dpi
    1: 850dpi (active) (default)
  Button: 0 is mapped to 'button 1'
  Button: 1 is mapped to 'button 2'
  Button: 2 is mapped to 'button 3'
  Button: 3 is mapped to macro '↕KEY_F13'
  Button: 4 is mapped to macro '↕KEY_F14'
  Button: 5 is mapped to macro '↕KEY_F15'
  Button: 6 is mapped to macro '↕KEY_F16'
  ...
  Button: 11 is mapped to 'profile-cycle-up'
```

## Quirks

- `ratbagd` sometimes needs a restart after unplug/repair to re-detect the mouse: `sudo systemctl restart ratbagd` (libratbag issue #1193).
- Piper's GUI dropdown is incomplete — no F13–F24, some media keys. Use `ratbagctl <device> button N action set macro KEY_F13` for those.
- The G903 has 5 onboard profiles (0–4). `ratbagctl <device> button N` operates on the currently active profile unless you prefix `profile P`.
- Setting button macros on only the active profile means an accidental press of the profile-cycle button (index 11) reverts to whatever the other enabled profile holds. Write to all enabled profiles to make cycling a no-op for thumb layout.
