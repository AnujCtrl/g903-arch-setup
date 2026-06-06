# Default mapping — workspace and focus navigation

The shipped default turns the G903's 4 thumb buttons into a workspace/window navigator and tells Hyprland to move the cursor along with focus changes.

**Important architectural note:** this default works **without makima**. It runs entirely as `mouse firmware → kernel evdev → Hyprland binds`. makima is only needed when you want **per-application** behavior; see [per-app-recipes.md](per-app-recipes.md) for that. Running makima with an empty or trivial config causes Hyprland to see every keypress twice (once from the real mouse, once from makima's virtual-keyboard echo) — so we keep makima disabled until per-app rules genuinely need it.

## Layout

```
        ┌─────────────────┐               ┌─────────────────┐
        │   LEFT SIDE     │               │   RIGHT SIDE    │
        │   ┌─────────┐   │               │   ┌─────────┐   │
        │   │  TOP    │───┼─► F14         │   │  TOP    │───┼─► F16
        │   │         │   │   workspace   │   │         │   │   workspace
        │   │         │   │   LEFT (e-1)  │   │         │   │   RIGHT (e+1)
        │   └─────────┘   │               │   └─────────┘   │
        │   ┌─────────┐   │               │   ┌─────────┐   │
        │   │  BOTTOM │───┼─► F13         │   │  BOTTOM │───┼─► F15
        │   │         │   │   window      │   │         │   │   window
        │   │         │   │   PREV (cyc)  │   │         │   │   NEXT (cyc)
        │   └─────────┘   │               │   └─────────┘   │
        └─────────────────┘               └─────────────────┘

       TOP row    -> workspace navigation (left = prev, right = next)
       BOTTOM row -> window cycling within the active workspace
```

| Physical | `ratbagctl` index | Key emitted | Keycode | Hyprland action |
|---|---|---|---|---|
| Top-left thumb | 4 | `F14` | 192 | `workspace, e-1` (workspace left) |
| Top-right thumb | 6 | `F16` | 194 | `workspace, e+1` (workspace right) |
| Bottom-left thumb | 3 | `F13` | 191 | `cyclenext, prev` (previous window) |
| Bottom-right thumb | 5 | `F15` | 193 | `cyclenext` (next window) |
| Wheel tilt **left** | 9 | `F23` | 201 | `sendshortcut, CTRL, Insert, activewindow` (Omarchy universal **copy**) |
| Wheel tilt **right** | 10 | `F24` | 202 | `sendshortcut, SHIFT, Insert, activewindow` (Omarchy universal **paste**) |

Mental model: **top row = workspaces, bottom row = windows. Left side = previous, right side = next. Wheel tilt = clipboard (left = take, right = give).**

### Why `Ctrl+Insert` / `Shift+Insert` for copy/paste

This is Omarchy's pattern (see `~/.local/share/omarchy/default/hypr/bindings/clipboard.conf`). It's the **universal** clipboard chord on Linux/Wayland: terminals don't intercept `Ctrl+Insert` the way they intercept `Ctrl+C` (SIGINT), so the same gesture works in your shell, your browser, your IDE, and Electron apps without a per-app override. Hyprland's `sendshortcut` dispatcher synthesizes the chord and sends it to the focused window.

### Why F23/F24 (not F19/F20) for the wheel tilts

On some xkb layouts, the keycode for `F20` (198) aliases to the `XF86AudioMicMute` keysym — Omarchy binds that to its mic-mute toggle, so tilting the wheel right was muting the microphone as a side effect. `F23` (201) and `F24` (202) sit above any standard media-key range. The only known overlap is Omarchy's Omarchy-menu binding on **SUPER+SHIFT+code:201**, but that requires the modifier to be held — bare wheel-tilt presses don't trigger it.

## Why `cyclenext` instead of `movefocus l/r`

`movefocus l` does a strictly-directional focus move based on Hyprland's layout tree. With a vertical split — say a top window and a bottom window side-by-side with a third window — pressing left/right from the top window can never reach the bottom one; you'd need `movefocus d`. That's a UX wart for a "give me the next window" gesture.

`cyclenext` iterates every window on the active workspace in tab order (with `, prev` for backward cycling). A single pair of buttons covers every window regardless of layout, including stacked / tabbed / vertically-split arrangements.

## Why F13–F16

These keycodes exist in the standard keymap but no physical keyboard ships with them. Using them means:

- No conflict with regular keyboard chords or any app's built-in shortcut.
- Each thumb button has a 1:1 keycode that Hyprland binds cleanly.
- If you add per-app makima overrides later, they can transform F13–F16 into anything else — the mouse layer doesn't need re-configuring.

The Hyprland snippet uses the `code:N` form (e.g. `bind = , code:191, ...`) rather than the keysym form (`bind = , F13, ...`). Both work on most layouts; `code:N` is more portable because it bypasses xkb keysym remapping that some users have customized.

## Cursor follows focus

`cursor:warp_on_change_workspace = 1` makes the cursor jump to the focused window when you switch workspaces. `movefocus` already warps the cursor by default (the underlying knob is `cursor:no_warps`, which is `false` by default in Hyprland 0.55+) — no extra config needed for the right-side buttons.

If you ever want to *disable* warping entirely, set `cursor:no_warps = true` (suppresses everything) or `cursor:warp_on_change_workspace = 0` (workspace switches only).

## Applying the default

Run from the repo root:

```bash
./scripts/apply-defaults.sh
```

What it does:

1. Activates profile 0 on the mouse (known baseline).
2. Writes `KEY_F13`–`KEY_F16` to **buttons 3, 4, 5, 6** on every enabled onboard profile.
3. Resets wheel-tilt buttons (9, 10) to their native `wheel-left` / `wheel-right` actions (so they horizontally scroll, not act as browser-zoom macros).
4. Installs `hyprland/g903.conf` to `~/.config/hypr/g903.conf`.
5. Appends `source = ~/.config/hypr/g903.conf` to `~/.config/hypr/hyprland.conf` (idempotent — only adds if not already present).
6. Runs `hyprctl reload`.
7. Ensures the `makima` service is stopped — global defaults don't need it.

### Why all enabled profiles

The G903 stores 5 onboard profiles (0–4) and the profile-cycle button (index 11, on the underside) rotates through the *enabled* ones. If you set only the active profile, an accidental press of the cycle button reverts to the old layout. Writing the F13–F16 mapping to every enabled profile makes the cycle button a no-op for the thumb layout while still letting you cycle DPI / LED presets per profile.

## Verifying after install

Press each thumb button and watch the result:

- Each press should produce exactly **one** workspace switch or focus movement (no doubles).
- If you see doubles, the makima service may have re-enabled itself: `sudo systemctl stop makima` and re-test.
- For a definitive read of what each button emits, use `evtest`:

```bash
sudo pacman -S evtest                 # one-time
# find event node
grep -B1 -A4 "Logitech G903" /proc/bus/input/devices
evtest /dev/input/eventN              # then press buttons
```

You should see `KEY_F13` … `KEY_F16` with `value 1` (press) and `value 0` (release) for each button. See [diagnostics.md](diagnostics.md) for the full debugging methodology.

## Flipping a pair

If "top-left = next workspace" feels backwards, edit `~/.config/hypr/g903.conf` and swap the dispatcher arguments on the relevant pair. Example — make top-left = prev, bottom-left = next:

```hypr
bind = , code:192, workspace, e-1     # top-left (was e+1)
bind = , code:191, workspace, e+1     # bottom-left (was e-1)
```

Reload with `hyprctl reload`. No mouse-side changes needed.

## Reverting

```bash
# Restore mouse buttons to defaults
ratbagctl <device> button 3 action set button 4
ratbagctl <device> button 4 action set button 5
ratbagctl <device> button 5 action set button 6
ratbagctl <device> button 6 action set button 7

# Remove the source line from hyprland.conf manually
hyprctl reload
```
