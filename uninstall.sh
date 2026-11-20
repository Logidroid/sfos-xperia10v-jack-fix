#!/bin/sh
# Remove sfos-xperia10v-jack-fix (v1 boot override + v2 timer/session apply).
set -eu

APP=sfos-xperia10v-jack-fix
FIX="${XDG_DATA_HOME:-$HOME/.local/share}/${APP}"
RUNTIME_DROPIN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd/user/pulseaudio.service.d"
RUNTIME_DROPIN="${RUNTIME_DROPIN_DIR}/jack-runtime.conf"
BIN="${XDG_BIN_HOME:-$HOME/.local/bin}"

echo "==> Removing sfos-xperia10v-jack-fix (current + v1/v2 leftovers)"

systemctl --user disable --now jack-audio-fix.timer 2>/dev/null || true
systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true
systemctl --user reset-failed jack-audio-fix.service jack-audio-fix.timer 2>/dev/null || true

# Clear the session CONFIG override only if our runtime drop-in is present.
if [ -f "${RUNTIME_DROPIN}" ] && grep -F -q "${FIX}/pulseaudio.env" "${RUNTIME_DROPIN}" 2>/dev/null; then
  systemctl --user unset-environment CONFIG 2>/dev/null || true
fi
rm -f "${RUNTIME_DROPIN}"
rmdir "${RUNTIME_DROPIN_DIR}" 2>/dev/null || true

# Units, v1 brick drop-in, wants links — BOTH config homes
for h in "$HOME/.config" "${XDG_CONFIG_HOME:-$HOME/.config}"; do
  rm -f "$h/systemd/user/pulseaudio.service.d/jack-fix.conf"
  rm -f "$h/systemd/user/jack-audio-fix.service" "$h/systemd/user/jack-audio-fix.timer"
  rm -f "$h/systemd/user/default.target.wants/jack-audio-fix.service"
  rm -f "$h/systemd/user/user-session.target.wants/jack-audio-fix.service"
  rm -f "$h/systemd/user/timers.target.wants/jack-audio-fix.timer"
  rmdir "$h/systemd/user/pulseaudio.service.d" 2>/dev/null || true
done

# Helpers: current bin dir + legacy PATH locations
rm -f "${BIN}/apply-jack-policy.sh" "${BIN}/reload-droid-jack.sh"
rm -f "${HOME}/bin/apply-jack-policy.sh" "${HOME}/bin/reload-droid-jack.sh"
rm -rf "${HOME}/bin/audio-jack-fix"

# Data dirs: current + legacy v1/v2
rm -rf "${FIX}"
rm -rf "$HOME/audio-jack-fix" "${XDG_DATA_HOME:-$HOME}/audio-jack-fix"

systemctl --user daemon-reload
systemctl --user restart pulseaudio.service 2>/dev/null || true

echo "Removed jack fix (units, runtime override, ${FIX}, legacy ~/bin and ~/audio-jack-fix)."
echo "PulseAudio uses the stock Sailfish config."
