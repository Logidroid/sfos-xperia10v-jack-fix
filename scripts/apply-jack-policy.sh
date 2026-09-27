#!/bin/sh
# Hot-swap module-droid-card to use patched audio policy (wired jack ports).
# Must run AFTER lipstick is up — never override pulseaudio.service at boot.
set -eu

FIX="${HOME}/audio-jack-fix"
CFG="${FIX}/audio_policy_configuration.xml"
LOG="${FIX}/apply.log"

log() { echo "$@" | tee -a "$LOG" 2>/dev/null || echo "$@"; }

mkdir -p "$FIX"
echo "---- $(date -Iseconds 2>/dev/null || date) ----" >>"$LOG" 2>/dev/null || true

if [ ! -f "$CFG" ]; then
  log "ERROR: missing $CFG — run install.sh first"
  exit 1
fi

# Wait for Pulse
i=0
while [ "$i" -lt 60 ]; do
  pactl info >/dev/null 2>&1 && break
  sleep 0.5
  i=$((i + 1))
done
if ! pactl info >/dev/null 2>&1; then
  log "ERROR: PulseAudio not available"
  exit 1
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
  exit 0
fi

log "Reloading module-droid-card with patched policy..."

# Unload existing droid-card modules (stock has no wired ports)
pactl list modules short 2>/dev/null | awk '/module-droid-card/ {print $1}' | while read -r idx; do
  [ -n "$idx" ] || continue
  log "unload module $idx"
  pactl unload-module "$idx" 2>/dev/null || true
done

sleep 1

# If Pulse died, let systemd bring it back then unload stock card again
if ! pactl info >/dev/null 2>&1; then
  log "Pulse restarted after unload — waiting..."
  systemctl --user start pulseaudio.service 2>/dev/null || true
  sleep 2
  i=0
  while [ "$i" -lt 30 ]; do
    pactl info >/dev/null 2>&1 && break
    sleep 0.5
    i=$((i + 1))
  done
  pactl list modules short 2>/dev/null | awk '/module-droid-card/ {print $1}' | while read -r idx; do
    [ -n "$idx" ] || continue
    pactl unload-module "$idx" 2>/dev/null || true
  done
  sleep 0.5
fi

if ! pactl load-module module-droid-card rate=48000 hw_volume=false source_format=s24-32le "config=${CFG}" >>"$LOG" 2>&1; then
  log "ERROR: failed to load module-droid-card with config"
  # try to restore audio
  systemctl --user restart pulseaudio.service 2>/dev/null || true
  exit 1
fi

sleep 1
if pactl list cards 2>/dev/null | grep -q output-wired_headphone; then
  log "OK: wired headphone port available"
  select_jack_port
  exit 0
fi

log "WARN: module loaded but wired ports not visible"
exit 1
