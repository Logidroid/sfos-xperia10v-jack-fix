#!/bin/sh
# Install Xperia 10 V wired jack workaround (SAFE v2).
# - Does NOT override pulseaudio.service at boot (that caused infinite loading).
# - Applies patched policy AFTER lipstick is up.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
FIX="${HOME}/audio-jack-fix"
UNIT_DIR="${HOME}/.config/systemd/user"
DROPIN_DIR="${UNIT_DIR}/pulseaudio.service.d"

echo "==> sfos-xperia10v-jack-fix v2 (post-lipstick, no boot Pulse override)"
echo "==> Install dir: ${FIX}"

if [ ! -f /vendor/etc/primary_audio_policy_configuration.xml ]; then
  echo "ERROR: /vendor/etc/primary_audio_policy_configuration.xml missing."
  exit 1
fi

if ! grep -q AUDIO_DEVICE_OUT_SPEAKER /vendor/etc/primary_audio_policy_configuration.xml; then
  echo "ERROR: unexpected audio policy file."
  exit 1
fi

# Remove dangerous v1 boot override if present
if [ -f "${DROPIN_DIR}/jack-fix.conf" ]; then
  echo "==> Removing unsafe v1 Pulse drop-in (jack-fix.conf)"
  rm -f "${DROPIN_DIR}/jack-fix.conf"
fi

mkdir -p "${FIX}" "${HOME}/bin" "${UNIT_DIR}"

cp /vendor/etc/audio_policy_configuration.xml \
   /vendor/etc/primary_audio_policy_configuration.xml \
   /vendor/etc/usb_audio_policy_configuration.xml \
   /vendor/etc/r_submix_audio_policy_configuration.xml \
   /vendor/etc/bluetooth_audio_policy_configuration_7_0.xml \
   /vendor/etc/audio_policy_volumes.xml \
   /vendor/etc/default_volume_tables.xml \
   "${FIX}/"

cp "${FIX}/primary_audio_policy_configuration.xml" \
   "${FIX}/primary_audio_policy_configuration.xml.orig"

python3 "${REPO_DIR}/scripts/patch_policy.py" \
  "${FIX}/primary_audio_policy_configuration.xml"

cp "${REPO_DIR}/scripts/apply-jack-policy.sh" "${HOME}/bin/apply-jack-policy.sh"
chmod +x "${HOME}/bin/apply-jack-policy.sh"
# Keep legacy name as alias
cp "${HOME}/bin/apply-jack-policy.sh" "${HOME}/bin/reload-droid-jack.sh"
chmod +x "${HOME}/bin/reload-droid-jack.sh"

# Apply only after UI (lipstick) is up — never blocks unlock spinner
cat > "${UNIT_DIR}/jack-audio-fix.service" << EOF
[Unit]
Description=Xperia jack fix: apply wired audio policy after UI is up
After=lipstick.service pulseaudio.service
Wants=pulseaudio.service

[Service]
Type=oneshot
# Let the session finish settling after unlock
ExecStartPre=/bin/sleep 8
ExecStart=${HOME}/bin/apply-jack-policy.sh
RemainAfterExit=yes

[Install]
WantedBy=user-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable jack-audio-fix.service

echo "==> Applying once now (UI already up)..."
systemctl --user start jack-audio-fix.service || true
sleep 2

echo "==> Verification"
if pactl list cards 2>/dev/null | grep -q output-wired_headphone; then
  echo "OK: output-wired_headphone port is present."
else
  echo "WARN: ports not visible yet. Manual: ~/bin/apply-jack-policy.sh"
fi
pactl list sinks 2>/dev/null | grep -E "Active Port:" || true

echo
echo "Done. Pulse boot config is STOCK (safe)."
echo "Jack policy is applied ~8s after lipstick."
echo "IMPORTANT: reboot once and confirm the UI comes up BEFORE relying on this."
echo "Uninstall: ${REPO_DIR}/uninstall.sh"
echo "Manual apply: ~/bin/apply-jack-policy.sh"
