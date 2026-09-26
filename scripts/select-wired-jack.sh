#!/bin/sh
# After Pulse starts with patched policy, route to wired jack if plugged.
set -eu
FIX="${HOME}/audio-jack-fix"

i=0
while [ "$i" -lt 40 ]; do
  pactl info >/dev/null 2>&1 && break
  sleep 0.25
  i=$((i + 1))
done
pactl info >/dev/null 2>&1 || exit 0

j=0
while [ "$j" -lt 40 ]; do
  pactl list cards 2>/dev/null | grep -q output-wired_headphone && break
  sleep 0.25
  j=$((j + 1))
done

SINK=$(pactl list sinks short 2>/dev/null | awk '/primary_output/ {print $2; exit}')
[ -z "${SINK:-}" ] && exit 0
pactl set-default-sink "$SINK" 2>/dev/null || true

pactl list sinks 2>/dev/null | grep -q "output-wired_headset" || exit 0

HEADPHONE=0
MIC=0
# Prefer jack device named "Headset Jack" over hardcoded eventN
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
elif [ "$HEADPHONE" = "1" ]; then
  pactl set-sink-port "$SINK" output-wired_headphone 2>/dev/null || true
fi
exit 0
