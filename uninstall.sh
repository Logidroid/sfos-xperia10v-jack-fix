#!/bin/sh
# Remove sfos-xperia10v-jack-fix (v1 boot override + v2 timer/session apply).
set -eu

FIX="${HOME}/audio-jack-fix"
UNIT_DIR="${HOME}/.config/systemd/user"
DROPIN_DIR="${UNIT_DIR}/pulseaudio.service.d"
DROPIN="${DROPIN_DIR}/jack-fix.conf"

systemctl --user disable --now jack-audio-fix.timer 2>/dev/null || true
systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true

# Clear session/runtime overrides
systemctl --user unset-environment CONFIG 2>/dev/null || true
rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd/user/pulseaudio.service.d/jack-runtime.conf"
rmdir "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd/user/pulseaudio.service.d" 2>/dev/null || true

rm -f "${UNIT_DIR}/jack-audio-fix.service"
rm -f "${UNIT_DIR}/jack-audio-fix.timer"
rm -f "${UNIT_DIR}/default.target.wants/jack-audio-fix.service"
rm -f "${UNIT_DIR}/user-session.target.wants/jack-audio-fix.service"
rm -f "${UNIT_DIR}/timers.target.wants/jack-audio-fix.timer"
rm -f "${DROPIN}"
rmdir "${DROPIN_DIR}" 2>/dev/null || true
rm -f "${HOME}/bin/reload-droid-jack.sh"
rm -f "${HOME}/bin/apply-jack-policy.sh"
rm -rf "${FIX}"

systemctl --user daemon-reload
systemctl --user restart pulseaudio.service 2>/dev/null || true

echo "Removed jack fix (v1 drop-in + v2 timer/service + session CONFIG + ~/audio-jack-fix)."
echo "PulseAudio uses the stock Sailfish config."
