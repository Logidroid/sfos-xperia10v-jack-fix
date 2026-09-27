#!/bin/sh
# Install Xperia 10 V wired jack workaround (SAFE v2.1).
#
# NEVER overrides pulseaudio.service at boot (v1 jack-fix.conf = spinner brick).
# Applies patched policy via a systemd USER TIMER after the session is up.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
FIX="${HOME}/audio-jack-fix"
UNIT_DIR="${HOME}/.config/systemd/user"
DROPIN_DIR="${UNIT_DIR}/pulseaudio.service.d"

echo "==> sfos-xperia10v-jack-fix v2.2 (runtime Pulse override after UI, stock boot)"
echo "==> Install dir: ${FIX}"

if [ ! -f /vendor/etc/primary_audio_policy_configuration.xml ]; then
  echo "ERROR: /vendor/etc/primary_audio_policy_configuration.xml missing."
  exit 1
fi

if ! grep -q AUDIO_DEVICE_OUT_SPEAKER /vendor/etc/primary_audio_policy_configuration.xml; then
  echo "ERROR: unexpected audio policy file."
  exit 1
fi

if grep -q AUDIO_DEVICE_OUT_WIRED_HEADPHONE /vendor/etc/primary_audio_policy_configuration.xml 2>/dev/null; then
  echo "NOTE: vendor already declares wired headphones — you may not need this."
fi

# ---- purge EVERY unsafe v1 artifact first ----
echo "==> Removing any v1 Pulse boot override / old units"
systemctl --user disable --now jack-audio-fix.timer 2>/dev/null || true
systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true
rm -f "${DROPIN_DIR}/jack-fix.conf"
rmdir "${DROPIN_DIR}" 2>/dev/null || true
rm -f "${UNIT_DIR}/jack-audio-fix.service"
rm -f "${UNIT_DIR}/jack-audio-fix.timer"
rm -f "${UNIT_DIR}/default.target.wants/jack-audio-fix.service"
rm -f "${UNIT_DIR}/user-session.target.wants/jack-audio-fix.service"
rm -f "${UNIT_DIR}/timers.target.wants/jack-audio-fix.timer"
# leftover v1 env/drop-in only — we rebuild pa.d below for post-UI restart
rm -f "${FIX}/pulseaudio.env" 2>/dev/null || true

mkdir -p "${FIX}/pa.d" "${HOME}/bin" "${UNIT_DIR}"

copy_req() {
  src=$1
  if [ ! -f "$src" ]; then
    echo "ERROR: required file missing: $src"
    exit 1
  fi
  cp "$src" "${FIX}/"
}

copy_opt() {
  src=$1
  if [ -f "$src" ]; then
    cp "$src" "${FIX}/"
  else
    echo "NOTE: optional missing: $src"
  fi
}

copy_req /vendor/etc/audio_policy_configuration.xml
copy_req /vendor/etc/primary_audio_policy_configuration.xml
copy_opt /vendor/etc/usb_audio_policy_configuration.xml
copy_opt /vendor/etc/r_submix_audio_policy_configuration.xml
copy_opt /vendor/etc/bluetooth_audio_policy_configuration_7_0.xml
copy_opt /vendor/etc/audio_policy_volumes.xml
copy_opt /vendor/etc/default_volume_tables.xml

cp "${FIX}/primary_audio_policy_configuration.xml" \
   "${FIX}/primary_audio_policy_configuration.xml.orig"

python3 "${REPO_DIR}/scripts/patch_policy.py" \
  "${FIX}/primary_audio_policy_configuration.xml"

python3 "${REPO_DIR}/scripts/rewrite_policy_hrefs.py" "${FIX}"

if ! grep -q AUDIO_DEVICE_OUT_WIRED_HEADPHONE \
    "${FIX}/primary_audio_policy_configuration.xml"; then
  echo "ERROR: patch did not take — aborting without enabling units"
  exit 1
fi

# Refuse to proceed if a Pulse drop-in somehow reappeared
if [ -f "${DROPIN_DIR}/jack-fix.conf" ]; then
  echo "ERROR: refusing install while ${DROPIN_DIR}/jack-fix.conf exists"
  exit 1
fi

# Custom Pulse start file used ONLY after UI via set-environment (not at boot)
if [ ! -f /etc/pulse/default_sailfish.pa ]; then
  echo "ERROR: /etc/pulse/default_sailfish.pa missing"
  exit 1
fi
cp /etc/pulse/default_sailfish.pa "${FIX}/default_sailfish.pa"
# Keep full stock pa.d, only override droid.pa (wired policy)
rm -rf "${FIX}/pa.d"
mkdir -p "${FIX}/pa.d"
if [ -d /etc/pulse/default_sailfish.pa.d ]; then
  cp -a /etc/pulse/default_sailfish.pa.d/. "${FIX}/pa.d/"
fi
sed "s|.include /etc/pulse/default_sailfish.pa.d|.include ${FIX}/pa.d|" \
  "${FIX}/default_sailfish.pa" > "${FIX}/default_sailfish.pa.tmp"
mv "${FIX}/default_sailfish.pa.tmp" "${FIX}/default_sailfish.pa"

# Prefer patching stock droid.pa if present; else write minimal loader
if [ -f "${FIX}/pa.d/droid.pa" ]; then
  # Replace any existing module-droid-card line(s) with patched config=
  if grep -q 'load-module module-droid-card' "${FIX}/pa.d/droid.pa"; then
    sed -i '/load-module module-droid-card/d' "${FIX}/pa.d/droid.pa"
  fi
  # Insert patched load at top
  {
    echo "### sfos-xperia10v-jack-fix — patched audio policy"
    echo "load-module module-droid-card rate=48000 hw_volume=false source_format=s24-32le config=${FIX}/audio_policy_configuration.xml"
    cat "${FIX}/pa.d/droid.pa"
  } > "${FIX}/pa.d/droid.pa.tmp"
  mv "${FIX}/pa.d/droid.pa.tmp" "${FIX}/pa.d/droid.pa"
else
  cat > "${FIX}/pa.d/droid.pa" << EOF
### sfos-xperia10v-jack-fix — patched audio policy
load-module module-droid-card rate=48000 hw_volume=false source_format=s24-32le config=${FIX}/audio_policy_configuration.xml
load-module module-udev-detect
EOF
fi

cp "${REPO_DIR}/scripts/apply-jack-policy.sh" "${HOME}/bin/apply-jack-policy.sh"
chmod +x "${HOME}/bin/apply-jack-policy.sh"
cp "${HOME}/bin/apply-jack-policy.sh" "${HOME}/bin/reload-droid-jack.sh"
chmod +x "${HOME}/bin/reload-droid-jack.sh"

# Service: NOT WantedBy any session target (only started by timer / manually)
cat > "${UNIT_DIR}/jack-audio-fix.service" << EOF
[Unit]
Description=Xperia jack fix: session Pulse restart with patched policy (after UI)
Documentation=file://${REPO_DIR}/README.md
After=pulseaudio.service
ConditionPathExists=${FIX}/default_sailfish.pa
Wants=pulseaudio.service

[Service]
Type=oneshot
Nice=10
TimeoutStartSec=90
ExecStart=${HOME}/bin/apply-jack-policy.sh
RemainAfterExit=yes
# No Restart= — a failure must not loop during the session

[Install]
# Intentionally empty: activated by jack-audio-fix.timer only
EOF

# Timer: fires once ~25s after user timers.target (well after unlock/UI)
cat > "${UNIT_DIR}/jack-audio-fix.timer" << EOF
[Unit]
Description=Delay Xperia jack fix until session has settled
After=pulseaudio.service

[Timer]
OnActiveSec=25
AccuracySec=2s
Unit=jack-audio-fix.service
Persistent=false

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable jack-audio-fix.timer
systemctl --user start jack-audio-fix.timer

echo "==> Applying once now (UI already up)..."
"${HOME}/bin/apply-jack-policy.sh" || true
sleep 1

echo "==> Verification"
echo "Pulse drop-in present? $( [ -f "${DROPIN_DIR}/jack-fix.conf" ] && echo YES_BAD || echo no_ok )"
systemctl --user is-enabled jack-audio-fix.timer 2>/dev/null || true
if pactl list cards 2>/dev/null | grep -q output-wired_headphone; then
  echo "OK: output-wired_headphone port is present."
else
  echo "WARN: wired ports not visible yet. Manual: ~/bin/apply-jack-policy.sh"
fi
pactl list sinks 2>/dev/null | grep -E "Active Port:" || true

echo
echo "Done."
echo "  - Pulse boot config: STOCK (safe — no drop-in)"
echo "  - After UI: timer sets session CONFIG and restarts Pulse once"
echo "IMPORTANT: reboot once. Unlock → confirm home screen works BEFORE daily use."
echo "Uninstall: ${REPO_DIR}/uninstall.sh"
