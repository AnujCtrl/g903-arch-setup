#!/usr/bin/env bash
# Apply the shipped default: thumb buttons -> F13-F16, Hyprland binds
# them to workspace/focus navigation, cursor warps on workspace switch.
#
# This default does NOT use makima — global Hyprland binds handle it.
# The script will stop the makima service if it's running, since running
# makima with an empty config causes Hyprland to see every keypress
# twice (real + virtual-keyboard echo). Re-enable makima only when you
# add per-app TOMLs that need it: see docs/per-app-recipes.md.
#
# Idempotent: safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
HYPR_DIR="$TARGET_HOME/.config/hypr"
HYPR_MAIN="$HYPR_DIR/hyprland.conf"
HYPR_SNIPPET="$HYPR_DIR/g903.conf"
SOURCE_LINE="source = $HYPR_DIR/g903.conf"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Find the device.
device="$(ratbagctl list 2>/dev/null | head -1 | cut -d: -f1)"
[ -n "$device" ] || err "No libratbag device found. Is the mouse connected and ratbagd running?"
log "Using libratbag device: $device"

# 2. Activate profile 0 (known baseline).
log "Activating profile 0"
ratbagctl "$device" profile active set 0 >/dev/null

# 3. Write F13-F16 to thumb buttons (slots 3,4,5,6) on EVERY enabled profile.
# Verified mapping (via evtest) on this hardware:
#   btn 3 -> bottom-left thumb
#   btn 4 -> top-left thumb
#   btn 5 -> bottom-right thumb
#   btn 6 -> top-right thumb
# If your G903 disagrees, see docs/diagnostics.md to remap.
enabled_profiles=$(
  ratbagctl "$device" info \
    | awk '/^Profile [0-9]+:/ && !/disabled/ { gsub(":", "", $2); print $2 }'
)
log "Writing F13-F16 to thumb buttons on profiles: $(echo $enabled_profiles | tr '\n' ' ')"
for p in $enabled_profiles; do
  # slot 3 -> F13, slot 4 -> F14, slot 5 -> F15, slot 6 -> F16
  for i in 3 4 5 6; do
    key="KEY_F$((13 + i - 3))"
    ratbagctl "$device" profile "$p" button "$i" action set macro "$key" >/dev/null
  done
done

# 4. Map wheel-tilt buttons to F23/F24 — Hyprland binds them to
# Omarchy's universal copy (Ctrl+Insert) / paste (Shift+Insert).
# This replaces the libratbag default of native horizontal scroll;
# you can revert with `action set special wheel-left/wheel-right`.
# F23/F24 (not F19/F20) because some xkb layouts alias the F20
# keycode to XF86AudioMicMute, which Omarchy binds to mic mute.
log "Mapping wheel-tilt buttons 9/10 to KEY_F23/KEY_F24 (copy/paste)"
for p in $enabled_profiles; do
  ratbagctl "$device" profile "$p" button 9  action set macro KEY_F23 >/dev/null
  ratbagctl "$device" profile "$p" button 10 action set macro KEY_F24 >/dev/null
done

log "Final thumb-button assignments:"
ratbagctl "$device" info | grep -E '^Profile|^  Button: [3-6]' | sed 's/^/    /'

# 5. Install Hyprland snippet.
if [ ! -d "$HYPR_DIR" ]; then
  warn "$HYPR_DIR does not exist — skipping Hyprland integration."
  warn "Manually copy hyprland/g903.conf into your compositor config."
  exit 0
fi

log "Installing $HYPR_SNIPPET"
install -Dm644 "$REPO_ROOT/hyprland/g903.conf" "$HYPR_SNIPPET"

# 6. Make sure hyprland.conf sources it (only append if missing).
if [ -f "$HYPR_MAIN" ]; then
  if grep -qF "$SOURCE_LINE" "$HYPR_MAIN"; then
    log "hyprland.conf already sources g903.conf"
  else
    log "Appending source line to hyprland.conf"
    printf '\n# G903 thumb-button defaults\n%s\n' "$SOURCE_LINE" >> "$HYPR_MAIN"
  fi
else
  warn "$HYPR_MAIN not found — created snippet but you'll need to source it manually."
fi

# 7. Mask makima (global defaults don't need it; running it would
#    create a virtual-keyboard echo that doubles every keypress).
#
# Why mask (not just disable):
#   - `disable` only removes the autostart symlink. Anything — a pacman
#     hook, an Omarchy update, a manual `systemctl start` — can quietly
#     bring it back, and the echo doubling returns silently.
#   - `mask` symlinks the unit to /dev/null. start/enable then fail
#     until you explicitly unmask. Survives reboots and package updates.
# To bring makima back for per-app overrides:
#   sudo systemctl unmask makima && sudo systemctl enable --now makima
# See docs/per-app-recipes.md for the per-app workflow.
if systemctl is-active --quiet makima 2>/dev/null; then
  log "Stopping makima service"
  sudo systemctl stop makima
fi
if [ "$(systemctl is-enabled makima 2>/dev/null)" != "masked" ]; then
  log "Masking makima service (irreversible until 'systemctl unmask makima')"
  sudo systemctl disable makima >/dev/null 2>&1 || true
  sudo systemctl mask makima
fi

# 8. Reload Hyprland if running.
if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  log "Reloading Hyprland"
  hyprctl reload
else
  warn "Hyprland not running — restart it or run \`hyprctl reload\` later."
fi

log "Done."
log "Verify each thumb button produces exactly ONE workspace or focus action:"
log "  - top-left   -> next workspace"
log "  - bottom-left-> previous workspace"
log "  - top-right  -> focus right"
log "  - bottom-right->focus left"
log "If a press jumps by 2: makima may have restarted — sudo systemctl stop makima"
log "If a pair feels inverted: swap dispatcher args in $HYPR_SNIPPET (no reflash needed)"
