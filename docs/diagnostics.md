# Diagnostic methodology

This walks through how the repo's default mapping was determined, and how to debug similar issues on your own setup. The core insight: stop interpreting events through compositor binds when verifying mouse behavior — go straight to the kernel.

## The layers, named

1. **Layer 1 — Mouse firmware.** Piper / `ratbagctl` writes button macros to the G903's onboard memory. Pressing a button → mouse emits a USB HID event → kernel evdev node receives one or more `EV_KEY` events.
2. **Layer 2a — makima.** Optional userspace daemon that monitors evdev devices, applies per-app remaps, and emits its own virtual keyboard via `/dev/uinput`.
3. **Layer 2b — Hyprland binds.** Compositor reads libinput → keysym/keycode events → matches `bind = ` rules → dispatches actions.

When something "feels wrong" (doubled events, missing events, wrong action), the layer matters. **Always check layer 1 first**, because if the kernel doesn't see clean events, no amount of layer-2 config will help.

## `evtest` — ground truth at layer 1

`evtest` reads raw events directly from an evdev node and prints them with timestamps. It bypasses compositor, libinput, makima, and xkb entirely. What it shows is exactly what the kernel received from the device.

```bash
sudo pacman -S evtest

# Find the mouse's evdev node
grep -B1 -A4 "Logitech G903" /proc/bus/input/devices

# Sample output:
#   N: Name="Logitech G903 LS"
#   ...
#   H: Handlers=sysrq kbd leds event9 mouse1

# Stream events
evtest /dev/input/event9
```

You'll see a list of supported event codes (long), then live events. Press a button; expect this shape for a clean tap:

```
Event: time 1780770164.406760, type 1 (EV_KEY), code 183 (KEY_F13), value 1
Event: time 1780770164.406760, -------------- SYN_REPORT ------------
Event: time 1780770164.537764, type 1 (EV_KEY), code 183 (KEY_F13), value 0
Event: time 1780770164.537764, -------------- SYN_REPORT ------------
```

That's one press: `value 1` (down) → `value 0` (up), ~131ms apart. If you see two `value 1` events for one click, the mouse firmware is doing something weird (rare). If you see one clean press here but the action fires twice in Hyprland, the problem is layer 2.

### Reading the device requires `input` group membership

`/dev/input/event9` is `crw-rw---- root input`. Be in the `input` group or use `sudo`:

```bash
groups | grep -q '\binput\b' && echo "ok" || echo "add yourself to input group"
sudo usermod -aG input "$USER"   # then log out / back in
```

The `makima-bin` package's udev rule grants `uaccess` on `/dev/uinput`, but doesn't add you to `input` — you have to do that yourself if you want `evtest`.

## Identifying which ratbagctl index = which physical button

`ratbagctl` exposes button slots 0–11, but they don't all correspond to physical positions in obvious ways. The libratbag wiki gives generic conventions; your unit may differ. The reliable method:

1. Assign each ratbagctl slot a unique `KEY_F*`:

   ```bash
   for i in 3 4 5 6 7 8; do
     key="KEY_F$((13 + i - 3))"   # F13 .. F18
     ratbagctl <device> button "$i" action set macro "$key"
   done
   ```

2. Run `evtest` on the mouse's event node.

3. Press each physical button once, deliberately. Note which `KEY_F*` appears for each press.

4. Buttons that produce no event in `evtest` either don't exist on your hardware or are wired to something other than a programmable slot (e.g. a hardware-only mode toggle).

5. Save the mapping to a personal note. **For my G903, the verified mapping was:**

   | Physical | ratbagctl index |
   |---|---|
   | bottom-left thumb | 3 |
   | top-left thumb | 4 |
   | bottom-right thumb | 5 |
   | top-right thumb | 6 |
   | (slot 7) | no physical button observed |
   | DPI button | 8 |

   See [button-layout.md](button-layout.md) for context.

## When notifications and dispatchers don't match `evtest`

If `evtest` shows a clean single press but Hyprland's bind fires twice, suspect layer 2 — most often makima.

### Confirming makima is the culprit

```bash
# Stop makima
sudo systemctl stop makima

# Press a thumb button. Single dispatch? makima was the cause.
# Re-enable if needed
sudo systemctl start makima
```

makima with `GRAB_DEVICE = "false"` and an empty `[remap]` doesn't grab the device, but it does create a virtual `makima-virtual-keyboard` and forward keyboard events through it. Hyprland sees the real kernel event AND the makima-virtual event = double dispatch.

Fixes (any of):

- Don't run makima at all when global Hyprland binds are enough (see [defaults.md](defaults.md)).
- Use `GRAB_DEVICE = "true"` plus an explicit identity remap (see [per-app-recipes.md](per-app-recipes.md)).
- Only run makima when a per-app TOML is actually active and grabs the device.

### Hyprland keysym vs `code:N`

If `bind = , F13, ...` doesn't fire but `evtest` shows `KEY_F13`, xkb may have remapped the keysym name. Switch to `bind = , code:191, ...` (where 191 = 183 + 8, the xkb scancode offset). The `apply-defaults.sh` script always uses `code:` form for portability.

## Layered de-bug procedure

If buttons are misbehaving in any way:

1. **Stop makima.** `sudo systemctl stop makima` removes layer 2a.
2. **Disable Hyprland binds.** Comment out the `source = ~/.config/hypr/g903.conf` line and `hyprctl reload`. Removes layer 2b.
3. **Run `evtest`** on the mouse's event node. Observe what raw events the kernel receives per button press.
4. From `evtest`, conclude:
   - Clean single events → mouse is fine. The problem is layer 2.
   - Multiple events per press → the mouse firmware macro is the problem (rare). Check the macro syntax in `ratbagctl button N action get`.
   - No events at all → button isn't wired to a programmable slot, or the kernel handler is wrong.
5. Re-enable layers one at a time and re-test, narrowing down which layer introduces the issue.

This is essentially `bisect` for input pipelines.

## Notification-driven testing (and its pitfalls)

Hyprland binds with `notify-send` are convenient — pressing a button pops a labeled notification, so you can see "which button fired what." But the dispatcher fires once per **bind match**, and the notification daemon (mako) shows the latest few notifications. Multiple presses or notification-history limits make this misleading.

Use `evtest` for ground truth. Use notifications for spot-checking the layer-2 wiring after `evtest` confirms layer 1.

## Useful one-liners

```bash
# List all enabled onboard profiles
ratbagctl <device> info | grep -E '^Profile [0-9]+:' | grep -v disabled

# Dump the current macro on every button of the active profile
ratbagctl <device> info | grep -E '^  Button:'

# Find the mouse's event node (kbd interface lives on the same node as mouse)
awk '/G903/{flag=1} flag && /Handlers/{print; flag=0}' /proc/bus/input/devices

# Watch makima ingest events
journalctl -u makima -f

# Show what Hyprland thinks is bound
hyprctl binds | less

# Confirm which keyboard devices Hyprland sees (including makima's virtual one)
hyprctl devices | grep -A3 'Keyboard at'
```
