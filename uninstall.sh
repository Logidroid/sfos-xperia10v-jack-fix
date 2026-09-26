#!/bin/sh
# Remove sfos-xperia10v-jack-fix user overrides (no root).
set -eu

FIX="${HOME}/audio-jack-fix"
UNIT_DIR="${HOME}/.config/systemd/user"
DROPIN="${UNIT_DIR}/pulseaudio.service.d/jack-fix.conf"

systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true
rm -f "${UNIT_DIR}/jack-audio-fix.service"
rm -f "${DROPIN}"
rm -f "${HOME}/bin/reload-droid-jack.sh"
rm -rf "${FIX}"

systemctl --user daemon-reload
systemctl --user stop pulseaudio.service 2>/dev/null || true
killall pulseaudio 2>/dev/null || true
sleep 1
systemctl --user start pulseaudio.service

echo "Removed jack fix. PulseAudio uses the stock Sailfish config again."
