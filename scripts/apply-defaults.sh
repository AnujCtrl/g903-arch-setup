#!/usr/bin/env bash
# Apply the shipped default: thumb buttons -> F13-F16, Hyprland binds
# them to workspace/focus navigation, cursor warps on workspace switch.
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

# 2. Activate profile 0 (so the layout matches a known baseline).
log "Activating profile 0"
ratbagctl "$device" profile active set 0 >/dev/null

# 3. Write F13-F16 to buttons 4-7 on EVERY enabled profile.
# The G903 has 5 onboard profiles; the profile-cycle button (index 11)
# rotates through enabled ones. If we only set the active profile,
# an accidental cycle reverts behavior. Setting all enabled profiles
# makes cycling a no-op for the thumb layout.
enabled_profiles=$(
  ratbagctl "$device" info \
    | awk '/^Profile [0-9]+:/ && !/disabled/ { gsub(":", "", $2); print $2 }'
)
log "Writing F13-F16 to enabled profiles: $(echo $enabled_profiles | tr '\n' ' ')"
for p in $enabled_profiles; do
  for i in 4 5 6 7; do
    key="KEY_F$((13 + i - 4))"
    ratbagctl "$device" profile "$p" button "$i" action set macro "$key" >/dev/null
  done
done

log "Final button assignments:"
ratbagctl "$device" info | grep -E '^Profile|^  Button: [4567]' | sed 's/^/    /'

# 3. Install Hyprland snippet.
if [ ! -d "$HYPR_DIR" ]; then
  warn "$HYPR_DIR does not exist — skipping Hyprland integration."
  warn "Manually copy hyprland/g903.conf into your compositor config."
  exit 0
fi

log "Installing $HYPR_SNIPPET"
install -Dm644 "$REPO_ROOT/hyprland/g903.conf" "$HYPR_SNIPPET"

# 4. Make sure hyprland.conf sources it (only append if missing).
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

# 5. Reload Hyprland if running.
if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  log "Reloading Hyprland"
  hyprctl reload
else
  warn "Hyprland not running — restart it or run \`hyprctl reload\` later."
fi

log "Done. Press each thumb button while watching: journalctl -u makima -f"
log "If any pair feels inverted, swap the dispatcher args in $HYPR_SNIPPET"
