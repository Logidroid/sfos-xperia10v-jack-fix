#!/bin/sh
# Remove sfos-xperia10v-jack-fix (v1 boot override + v2 post-lipstick).
set -eu

FIX="${HOME}/audio-jack-fix"
UNIT_DIR="${HOME}/.config/systemd/user"
DROPIN="${UNIT_DIR}/pulseaudio.service.d/jack-fix.conf"

systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true
rm -f "${UNIT_DIR}/jack-audio-fix.service"
rm -f "${DROPIN}"
rmdir "${UNIT_DIR}/pulseaudio.service.d" 2>/dev/null || true
rm -f "${HOME}/bin/reload-droid-jack.sh"
rm -f "${HOME}/bin/apply-jack-policy.sh"
rm -rf "${FIX}"

systemctl --user daemon-reload

# Restore stock droid card if needed
systemctl --user restart pulseaudio.service 2>/dev/null || true

echo "Removed jack fix (including any unsafe v1 Pulse drop-in)."
echo "PulseAudio uses the stock Sailfish config."
