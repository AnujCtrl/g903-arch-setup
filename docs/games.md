# Games with restrictive keybind UIs

Some games only let you bind a **single key** per action — modifier+letter combos are not accepted. This rules out the obvious "side button → Ctrl+C" pattern.

## The problem with F13–F24 in old games

F13–F24 are real scancodes in the standard keyboard tables. For modern apps they're ideal: no physical keyboard has them, so nothing conflicts. But:

- **LWJGL 2.x** (Minecraft 1.12 and earlier — includes GT:NH on 1.7.10) has inconsistent F13–F24 recognition. The Minecraft wiki and libgdx issue #5389 both confirm partial / broken support across drivers.
- Many older proprietary engines simply don't include the F13–F24 keycodes in their input tables.

So for games where binding may silently fail, pick something else.

## What to use instead

### 1. Native mouse buttons (no Piper change needed)

The G903's side, forward, back, and DPI buttons send `BTN_SIDE`, `BTN_EXTRA`, `BTN_FORWARD`, `BTN_BACK`. Most games (including Minecraft 1.7.10) accept these as `Mouse Button 4`, `Mouse Button 5`, etc. via the keybind UI — just click the keybind field, then press that physical button.

This uses zero of your "unused keyboard key" budget.

### 2. Unused real keyboard keys

These are in every standard keymap, accepted by every game's keybind UI, and almost certainly not on the user's physical keyboard if they're using a TKL / 60% layout:

| Group | Keys |
|---|---|
| Lock keys | `KEY_SCROLLLOCK`, `KEY_PAUSE`, `KEY_NUMLOCK` |
| Nav cluster | `KEY_INSERT`, `KEY_HOME`, `KEY_END`, `KEY_PAGEUP`, `KEY_PAGEDOWN`, `KEY_DELETE` |
| Numpad | `KEY_KP0` – `KEY_KP9`, `KEY_KPPLUS`, `KEY_KPMINUS`, `KEY_KPASTERISK`, `KEY_KPSLASH`, `KEY_KPDOT` |
| Right-side modifiers | `KEY_RIGHTCTRL`, `KEY_RIGHTSHIFT`, `KEY_RIGHTALT`, `KEY_RIGHTMETA` (if not bound elsewhere) |

That's roughly **25 conflict-free single keycode slots** — plenty for an 11-button mouse.

## Recommended game-focused Piper assignment

Leave native mouse-button events untouched (just bind them in the game), use unused keyboard keys for the rest:

| ratbagctl btn | Piper action | Game binds as |
|---|---|---|
| 0, 1, 2 | unchanged | LMB / RMB / MMB |
| 4 (thumb back) | leave as `BTN_BACK` | Mouse Button 4 |
| 5 (thumb fwd) | leave as `BTN_EXTRA` | Mouse Button 5 |
| 3 (top-front) | `KEY_INSERT` | Insert |
| 6 (opposite back) | `KEY_SCROLLLOCK` | ScrollLock |
| 7 (opposite fwd) | `KEY_HOME` | Home |
| 8 (DPI) | `KEY_PAUSE` | Pause/Break |
| 9 (tilt left) | `KEY_KPMINUS` | Numpad − |
| 10 (tilt right) | `KEY_KPPLUS` | Numpad + |
| 11 (profile) | `KEY_END` | End |

Each is a single keycode the keybind UI accepts on the first click.

## Setting unsupported-by-GUI keys via CLI

Piper's dropdown lacks some special keys. Use `ratbagctl` directly:

```bash
ratbagctl list                                                # find device codename
ratbagctl <device> button 3 action set macro KEY_INSERT
ratbagctl <device> button 6 action set macro KEY_SCROLLLOCK
ratbagctl <device> button 8 action set macro KEY_PAUSE
ratbagctl <device> button 9 action set macro KEY_KPMINUS
ratbagctl <device> button 10 action set macro KEY_KPPLUS
ratbagctl <device> button 11 action set macro KEY_END
```

Verify each with `action get`:

```bash
ratbagctl <device> button 3 action get
```

## Disabling makima inside the game

makima reads the focused window class and applies the matching TOML — or the fallback if no match. To make sure makima doesn't rewrite these keys for your game, either:

- **Don't create** a `<device>::<game_window_class>.toml` (the fallback `<device>.toml` applies, which is pure passthrough in this repo's default).
- **Or** create the per-game file with an empty `[remap]` and `GRAB_DEVICE = "false"` — same effect, explicit.

Get the game's window class:

```bash
hyprctl clients | grep -A4 -i minecraft     # adjust for your game
```

## Specific case: Minecraft 1.7.10 / GT:NH

GT:NH ships with the **Controlling** mod, which improves the vanilla keybind UI's handling of unusual keys. With Controlling installed, the assignments in the table above bind cleanly. Without Controlling, vanilla 1.7.10 still accepts native mouse buttons and the standard nav-cluster keys.

If a key still won't bind: try clicking the keybind slot first, then pressing the physical mouse button (not the keyboard). The game receives whatever the mouse + Piper emit, so this is the most direct test.
