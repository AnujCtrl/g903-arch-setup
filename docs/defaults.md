# Default mapping — workspace and focus navigation

The shipped default turns the G903's 4 thumb buttons into a workspace/window navigator and tells Hyprland to move the cursor along with focus changes.

## Layout

```
        ┌─────────────────┐
        │     LEFT SIDE   │   ──► workspace navigation
        │   ┌─────────┐   │
        │   │  upper  │───┼──► F14 = next workspace
        │   └─────────┘   │
        │   ┌─────────┐   │
        │   │  lower  │───┼──► F13 = previous workspace
        │   └─────────┘   │
        └─────────────────┘

        ┌─────────────────┐
        │   RIGHT SIDE    │   ──► focus navigation (within workspace)
        │   ┌─────────┐   │
        │   │  upper  │───┼──► F16 = focus right
        │   └─────────┘   │
        │   ┌─────────┐   │
        │   │  lower  │───┼──► F15 = focus left
        │   └─────────┘   │
        └─────────────────┘
```

| Physical | `ratbagctl` index | Key emitted | Hyprland action |
|---|---|---|---|
| Left lower | 4 | `F13` | `workspace, e-1` |
| Left upper | 5 | `F14` | `workspace, e+1` |
| Right lower | 6 | `F15` | `movefocus, l` |
| Right upper | 7 | `F16` | `movefocus, r` |

## Why F13–F16

These keycodes exist in the standard keymap but no physical keyboard ships with them. Using them means:

- No conflict with regular keyboard chords or any app's built-in shortcut.
- Each thumb button has a 1:1 keycode that Hyprland binds cleanly.
- If you add a per-app makima override later, it can transform F13–F16 into anything else — the mouse layer doesn't need re-configuring.

## Cursor follows focus

`cursor:warp_on_change_workspace = 1` makes the cursor jump to the focused window when you switch workspaces. `movefocus` already warps the cursor by default (the underlying knob is `cursor:no_warps`, which is `false` by default in Hyprland 0.55+) — no extra config needed for the right-side buttons.

If you ever want to *disable* warping entirely, set `cursor:no_warps = true` (suppresses everything) or `cursor:warp_on_change_workspace = 0` (workspace switches only).

## Applying the default

Run from the repo root:

```bash
./scripts/apply-defaults.sh
```

What it does:

1. Sets `ratbagctl` button 4–7 to `KEY_F13`–`KEY_F16` on the active G903 profile.
2. Installs `hyprland/g903.conf` to `~/.config/hypr/g903.conf`.
3. Appends `source = ~/.config/hypr/g903.conf` to `~/.config/hypr/hyprland.conf` (idempotent — only adds if not already present).
4. Runs `hyprctl reload`.

## Verifying after install

Press each thumb button and watch the result:

```bash
# Tail makima logs — every key the mouse emits will be logged here.
journalctl -u makima -f
```

You should see `F13`, `F14`, `F15`, `F16` correspond to the buttons described above. If they're reversed within a side (e.g. "left lower" actually fires `F14` instead of `F13`), just swap the dispatcher arguments in `~/.config/hypr/g903.conf` — no reflash needed.

## Reverting

```bash
# Restore buttons to default 'button N' behavior:
ratbagctl <device> button 4 action set button 4
ratbagctl <device> button 5 action set button 5
ratbagctl <device> button 6 action set button 6
ratbagctl <device> button 7 action set button 7

# Remove the source line from hyprland.conf manually, then:
hyprctl reload
```
