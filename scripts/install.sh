#!/usr/bin/env bash
# Idempotent setup for G903 + Piper + makima on Arch Linux.
# Re-running this script is safe: it skips already-completed steps.
#
# This installs everything but only enables the ratbagd daemon.
# makima is installed and configured but left stopped/disabled — it
# only needs to run when you add per-application overrides (see
# docs/per-app-recipes.md). For the shipped global default, see
# scripts/apply-defaults.sh which doesn't need makima at all.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
CONFIG_DIR="$TARGET_HOME/.config/makima"
OVERRIDE_DST="/etc/systemd/system/makima.service.d/override.conf"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }

# 1. Packages
need_install=()
for pkg in piper libratbag makima-bin; do
  if ! pacman -Q "$pkg" >/dev/null 2>&1; then
    need_install+=("$pkg")
  fi
done

if [ "${#need_install[@]}" -gt 0 ]; then
  log "Installing: ${need_install[*]}"
  sudo pacman -S --noconfirm --needed "${need_install[@]}"
else
  log "Packages already installed: piper libratbag makima-bin"
fi

# 2. systemd drop-in override (fixes empty User= and /home// placeholder)
log "Installing makima systemd drop-in for user $TARGET_USER"
tmp_override="$(mktemp)"
sed "s|__USER__|$TARGET_USER|g" "$REPO_ROOT/systemd/makima-override.conf" > "$tmp_override"
sudo install -Dm644 "$tmp_override" "$OVERRIDE_DST"
rm -f "$tmp_override"

# 3. Reload systemd; enable ratbagd only (makima stays disabled).
log "Reloading systemd and enabling ratbagd"
sudo systemctl daemon-reload
sudo systemctl enable --now ratbagd

# 4. Seed user config dir if empty.
if [ ! -d "$CONFIG_DIR" ]; then
  log "Creating $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
fi

if [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
  log "Seeding example configs into $CONFIG_DIR"
  cp -v "$REPO_ROOT"/examples/*.toml "$CONFIG_DIR/"
else
  warn "$CONFIG_DIR is not empty — leaving existing configs alone."
  warn "Copy individual examples manually if desired: ls $REPO_ROOT/examples"
fi

# 5. Health check
log "Verification:"
echo "    ratbagctl list:"
ratbagctl list 2>&1 | sed 's/^/      /'
echo "    services:"
systemctl is-active ratbagd makima 2>&1 | sed 's/^/      /'
echo "    config dir:"
ls -1 "$CONFIG_DIR" | sed 's/^/      /'

log "Done. Next steps:"
log "  - For the shipped workspace/focus defaults:  ./scripts/apply-defaults.sh"
log "  - For per-app overrides:                     sudo systemctl enable --now makima"
log "                                               then write TOMLs in $CONFIG_DIR"
log "  - For DPI / LEDs / extra macros:             launch piper"
