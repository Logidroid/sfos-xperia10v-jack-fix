#!/bin/sh
# Install Xperia 10 V (pdx235) wired jack workaround for official Sailfish OS.
# Run on the phone as defaultuser (Developer Mode). No root required.
set -eu

echo "ERROR: install disabled."
echo "The PulseAudio systemd override caused infinite loading after the"
echo "security code on reboot (session/lipstick never finishes starting)."
echo "See README.md and RECOVERY.md. Do not use this installer until fixed."
exit 1

REPO_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
FIX="${HOME}/audio-jack-fix"
UNIT_DIR="${HOME}/.config/systemd/user"
DROPIN_DIR="${UNIT_DIR}/pulseaudio.service.d"

echo "==> Target: Sailfish OS on Sony Xperia 10 V (pdx235 / XQ-DC*)"
echo "==> Install dir: ${FIX}"

if [ ! -f /vendor/etc/primary_audio_policy_configuration.xml ]; then
  echo "ERROR: /vendor/etc/primary_audio_policy_configuration.xml missing."
  echo "This fix is for Sailfish hybris devices with Android audio policy."
  exit 1
fi

if ! grep -q AUDIO_DEVICE_OUT_SPEAKER /vendor/etc/primary_audio_policy_configuration.xml; then
  echo "ERROR: unexpected audio policy file."
  exit 1
fi

if grep -q AUDIO_DEVICE_OUT_WIRED_HEADPHONE /vendor/etc/primary_audio_policy_configuration.xml 2>/dev/null; then
  echo "NOTE: vendor policy already declares wired headphones."
  echo "You may not need this workaround (or Jolla already fixed it)."
fi

mkdir -p "${FIX}/pa.d" "${DROPIN_DIR}" "${HOME}/bin"

# Copy policy stack from vendor (version-adaptive)
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

# Pulse config: copy Sailfish default and point includes at our pa.d
cp /etc/pulse/default_sailfish.pa "${FIX}/default_sailfish.pa"
# Replace only the default_sailfish.pa.d include line
sed "s|.include /etc/pulse/default_sailfish.pa.d|.include ${FIX}/pa.d|" \
  "${FIX}/default_sailfish.pa" > "${FIX}/default_sailfish.pa.tmp"
mv "${FIX}/default_sailfish.pa.tmp" "${FIX}/default_sailfish.pa"

cat > "${FIX}/pa.d/droid.pa" << EOF
### sfos-xperia10v-jack-fix — expose wired jack via patched audio policy
load-module module-droid-card rate=48000 hw_volume=false source_format=s24-32le config=${FIX}/audio_policy_configuration.xml
load-module module-udev-detect

.ifexists module-droid-glue.so
 .nofail
 load-module module-droid-glue
 .fail
.endif

.ifexists module-droid-hidl.so
 .nofail
 load-module module-droid-hidl
 .fail
.endif
EOF

cat > "${FIX}/pulseaudio.env" << EOF
HYBRIS_USE_VENDOR_NAMESPACE=yes
CONFIG="-n --file=${FIX}/default_sailfish.pa"
EOF

cat > "${DROPIN_DIR}/jack-fix.conf" << EOF
[Service]
# Override system /etc/sysconfig/pulseaudio CONFIG
EnvironmentFile=
EnvironmentFile=-/etc/sysconfig/pulseaudio
EnvironmentFile=-${FIX}/pulseaudio.env
EOF

cp "${REPO_DIR}/scripts/select-wired-jack.sh" "${HOME}/bin/reload-droid-jack.sh"
chmod +x "${HOME}/bin/reload-droid-jack.sh"
# Make script use this FIX dir
sed "s|^FIX=.*|FIX=\"${FIX}\"|" "${HOME}/bin/reload-droid-jack.sh" > "${HOME}/bin/reload-droid-jack.sh.tmp"
mv "${HOME}/bin/reload-droid-jack.sh.tmp" "${HOME}/bin/reload-droid-jack.sh"
chmod +x "${HOME}/bin/reload-droid-jack.sh"

cat > "${UNIT_DIR}/jack-audio-fix.service" << EOF
[Unit]
Description=Select wired jack port when headset plugged (Xperia 10 V fix)
After=pulseaudio.service
Requires=pulseaudio.service

[Service]
Type=oneshot
ExecStart=${HOME}/bin/reload-droid-jack.sh
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable jack-audio-fix.service

echo "==> Restarting PulseAudio..."
systemctl --user stop pulseaudio.service 2>/dev/null || true
killall pulseaudio 2>/dev/null || true
sleep 2
systemctl --user start pulseaudio.service
sleep 2
systemctl --user start jack-audio-fix.service || true
sleep 1

echo "==> Verification"
if pactl list cards 2>/dev/null | grep -q output-wired_headphone; then
  echo "OK: output-wired_headphone port is present."
else
  echo "WARN: wired ports not visible yet. Try: systemctl --user restart pulseaudio"
fi

pactl list sinks 2>/dev/null | grep -E "Active Port:" || true
echo
echo "Done. Plug headphones and play audio."
echo "Uninstall: ${REPO_DIR}/uninstall.sh"
