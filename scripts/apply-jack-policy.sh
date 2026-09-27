#!/bin/sh
# Apply patched jack policy AFTER the UI is already up.
#
# SAFETY:
# - Never write a PERSISTENT pulseaudio.service.d drop-in under ~/.config
#   (that was the v1 spinner brick).
# - Write only a RUNTIME drop-in under $XDG_RUNTIME_DIR (gone after reboot),
#   so the next boot always starts Pulse stock until this timer runs again.
# - Environment= overrides EnvironmentFile=CONFIG from /etc/sysconfig/pulseaudio.
set -u

FIX="${HOME}/audio-jack-fix"
CFG="${FIX}/audio_policy_configuration.xml"
PRIMARY="${FIX}/primary_audio_policy_configuration.xml"
PA_FILE="${FIX}/default_sailfish.pa"
LOG="${FIX}/apply.log"
LOCK="${FIX}/apply.lock"
RUNTIME_DROPIN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd/user/pulseaudio.service.d"
RUNTIME_DROPIN="${RUNTIME_DROPIN_DIR}/jack-runtime.conf"
# Hard refusal: never recreate the v1 persistent path
PERSIST_DROPIN="${HOME}/.config/systemd/user/pulseaudio.service.d/jack-fix.conf"

log() { echo "$@" | tee -a "$LOG" 2>/dev/null || echo "$@"; }

mkdir -p "$FIX"
echo "---- $(date -Iseconds 2>/dev/null || date) ----" >>"$LOG" 2>/dev/null || true

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK"
  flock -n 9 || { log "Another apply in progress — skip"; exit 0; }
fi

ensure_pulse() {
  i=0
  while [ "$i" -lt 40 ]; do
    pactl info >/dev/null 2>&1 && return 0
    sleep 0.5
    i=$((i + 1))
  done
  systemctl --user start pulseaudio.service 2>/dev/null || true
  sleep 2
  pactl info >/dev/null 2>&1
}

clear_runtime_override() {
  rm -f "$RUNTIME_DROPIN"
  rmdir "$RUNTIME_DROPIN_DIR" 2>/dev/null || true
  systemctl --user unset-environment CONFIG 2>/dev/null || true
  systemctl --user daemon-reload 2>/dev/null || true
}

restore_stock_pulse() {
  log "Restoring stock Pulse (clear runtime override)..."
  clear_runtime_override
  systemctl --user restart pulseaudio.service 2>/dev/null || true
  sleep 2
  ensure_pulse || log "ERROR: Pulse still unreachable after restore"
}

finish_ok() {
  if pactl info >/dev/null 2>&1; then
    exit 0
  fi
  restore_stock_pulse
  exit 0
}

# Abort if someone reintroduced the dangerous persistent drop-in
if [ -f "$PERSIST_DROPIN" ]; then
  log "ERROR: persistent $PERSIST_DROPIN present — removing and refusing apply"
  rm -f "$PERSIST_DROPIN"
  rmdir "$(dirname "$PERSIST_DROPIN")" 2>/dev/null || true
  systemctl --user daemon-reload 2>/dev/null || true
  restore_stock_pulse
  exit 0
fi

if [ ! -f "$CFG" ] || [ ! -f "$PRIMARY" ] || [ ! -f "$PA_FILE" ]; then
  log "ERROR: missing policy/pa files in $FIX — run install.sh"
  exit 0
fi

if ! grep -q AUDIO_DEVICE_OUT_WIRED_HEADPHONE "$PRIMARY" 2>/dev/null; then
  log "ERROR: primary policy is not patched"
  exit 0
fi

if ! ensure_pulse; then
  log "ERROR: PulseAudio not available before apply"
  exit 0
fi

select_jack_port() {
  SINK=$(pactl list sinks short 2>/dev/null | awk '/primary_output/ {print $2; exit}')
  [ -z "${SINK:-}" ] && return 0
  pactl set-default-sink "$SINK" 2>/dev/null || true
  pactl list sinks 2>/dev/null | grep -q "output-wired_headset" || return 0

  HEADPHONE=0
  MIC=0
  JACK_DEV=""
  for f in /sys/class/input/event*/device/name; do
    [ -f "$f" ] || continue
    if grep -qi "Headset Jack" "$f" 2>/dev/null; then
      JACK_DEV="/dev/input/$(basename "$(dirname "$(dirname "$f")")")"
      break
    fi
  done
  [ -z "$JACK_DEV" ] && [ -e /dev/input/event4 ] && JACK_DEV=/dev/input/event4

  if [ -n "$JACK_DEV" ] && [ -e "$JACK_DEV" ]; then
    eval "$(python3 - "$JACK_DEV" <<'PY'
import fcntl, array, os, sys
dev = sys.argv[1]
def _IOR(t, nr, size):
    return (2 << 30) | (ord(t) << 8) | nr | (size << 16)
try:
    fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
    buf = array.array("B", [0] * 8)
    fcntl.ioctl(fd, _IOR("E", 0x1b, 8), buf, True)
    bits = int.from_bytes(buf, "little")
    os.close(fd)
    print("HEADPHONE=%d" % bool(bits & (1 << 2)))
    print("MIC=%d" % bool(bits & (1 << 4)))
except Exception:
    print("HEADPHONE=0")
    print("MIC=0")
PY
)"
  fi

  if [ "$HEADPHONE" = "1" ] && [ "$MIC" = "1" ]; then
    pactl set-sink-port "$SINK" output-wired_headset 2>/dev/null || true
    pactl set-source-port source.primary_input input-wired_headset 2>/dev/null || true
    log "Routed to output-wired_headset"
  elif [ "$HEADPHONE" = "1" ]; then
    pactl set-sink-port "$SINK" output-wired_headphone 2>/dev/null || true
    log "Routed to output-wired_headphone"
  fi
}

if pactl list cards 2>/dev/null | grep -q output-wired_headphone; then
  log "Wired ports already present"
  select_jack_port
  finish_ok
fi

log "Installing RUNTIME-only Pulse override (cleared on reboot): $RUNTIME_DROPIN"
mkdir -p "$RUNTIME_DROPIN_DIR"

# EnvironmentFile parsing keeps quoted CONFIG= with spaces (Environment= truncates).
# Clear unit EnvironmentFile list, re-add stock (HYBRIS_*) then our CONFIG override.
cat > "${FIX}/pulseaudio.env" << EOF
CONFIG="-n --file=${PA_FILE}"
EOF

cat > "$RUNTIME_DROPIN" << EOF
[Service]
EnvironmentFile=
EnvironmentFile=-/etc/sysconfig/pulseaudio
EnvironmentFile=-${FIX}/pulseaudio.env
EOF

systemctl --user daemon-reload 2>/dev/null || true
log "Restarting Pulse with patched policy..."
systemctl --user restart pulseaudio.service 2>/dev/null || true
sleep 2

if ! ensure_pulse; then
  log "ERROR: Pulse did not come back — restoring stock"
  restore_stock_pulse
  finish_ok
fi

# Prove we actually used our file (module argument contains FIX path)
MOD_ARGS=$(pactl list modules 2>/dev/null | tr '\n' ' ' | sed 's/Module #/\nModule #/g' | grep module-droid-card | head -1)
log "droid-card: ${MOD_ARGS:-unknown}"

if echo "${MOD_ARGS:-}" | grep -q "$FIX"; then
  log "OK: module-droid-card uses patched config path"
elif pactl list modules short 2>/dev/null | grep -q module-droid-card; then
  log "WARN: module-droid-card loaded but args may still be stock"
fi

if pactl list cards 2>/dev/null | grep -q output-wired_headphone; then
  log "OK: wired headphone port available"
  select_jack_port
  finish_ok
fi

log "WARN: Pulse up but wired ports still missing — restoring stock"
restore_stock_pulse
finish_ok
