#!/bin/sh
# Remove sfos-xperia10v-jack-fix (v1 boot override + v2 timer/session apply).
set -eu

APP=sfos-xperia10v-jack-fix
FIX="${XDG_DATA_HOME:-$HOME/.local/share}/${APP}"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
DROPIN_DIR="${UNIT_DIR}/pulseaudio.service.d"
PERSIST_DROPIN="${DROPIN_DIR}/jack-fix.conf"
RUNTIME_DROPIN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd/user/pulseaudio.service.d"
RUNTIME_DROPIN="${RUNTIME_DROPIN_DIR}/jack-runtime.conf"
BIN="${XDG_BIN_HOME:-$HOME/.local/bin}"

systemctl --user disable --now jack-audio-fix.timer 2>/dev/null || true
systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true

# Clear session/runtime overrides
systemctl --user unset-environment CONFIG 2>/dev/null || true
rm -f "${RUNTIME_DROPIN}"
rmdir "${RUNTIME_DROPIN_DIR}" 2>/dev/null || true

rm -f "${UNIT_DIR}/jack-audio-fix.service"
rm -f "${UNIT_DIR}/jack-audio-fix.timer"
rm -f "${UNIT_DIR}/default.target.wants/jack-audio-fix.service"
rm -f "${UNIT_DIR}/user-session.target.wants/jack-audio-fix.service"
rm -f "${UNIT_DIR}/timers.target.wants/jack-audio-fix.timer"
rm -f "${PERSIST_DROPIN}"
rmdir "${DROPIN_DIR}" 2>/dev/null || true
rm -f "${BIN}/apply-jack-policy.sh"
rm -f "${BIN}/reload-droid-jack.sh"
# Legacy v1/v2 locations; explicit migration/cleanup comes in a later phase.
rm -f "${HOME}/bin/reload-droid-jack.sh"
rm -f "${HOME}/bin/apply-jack-policy.sh"
rm -rf "${HOME}/audio-jack-fix"
rm -rf "${FIX}"

systemctl --user daemon-reload
systemctl --user restart pulseaudio.service 2>/dev/null || true

echo "Removed jack fix (units, runtime override, ${FIX}, legacy ~/bin and ~/audio-jack-fix)."
echo "PulseAudio uses the stock Sailfish config."
