# Recovery — infinite loading after security code

If you installed this workaround and after reboot the phone stays on a
**spinner forever after the PIN/code**, the user session is stuck (often
PulseAudio / lipstick). The jack fix lives in your **home directory**.

## 1) Prefer: SSH while the spinner is showing

After you enter the security code, `/home` is unlocked. If Wi‑Fi reconnects
(or USB developer networking works):

```sh
ssh -i ~/.ssh/qtc_id -o IdentitiesOnly=yes defaultuser@PHONE_IP
```

Then:

```sh
systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true
rm -f ~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf
rm -f ~/.config/systemd/user/jack-audio-fix.service
rm -rf ~/audio-jack-fix
rm -f ~/bin/reload-droid-jack.sh
systemctl --user daemon-reload
systemctl --user restart pulseaudio lipstick || true
# if still stuck:
devel-su reboot
```

Or run `./uninstall.sh` from a copy of this repo on the phone.

`172.28.172.1` only works with **USB Developer Mode** networking. A plain
“USB device detected” notification is **not** enough (no `usb0`).

## 2) No SSH / no Wi‑Fi: reflash or factory reset

You must clear the home overlay (or wipe `/home`).

1. Force power off: hold **Power + Volume Up** until it reboots/off.
2. Enter **fastboot**: phone off → hold **Volume Up** → plug USB.
3. On PC: `fastboot devices` must list the phone.
4. Flash Sailfish OS for Xperia 10 V from your [Jolla account](https://account.jolla.com/)
   flash package (**accept data wipe / clear device** so
   `~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf` is removed).

Reflashing the system **without** wiping home can leave the broken drop-in
in place and the spinner will return after unlock.

## Files that cause the hang

- `~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf`
- `~/.config/systemd/user/jack-audio-fix.service`
- `~/audio-jack-fix/` (custom Pulse config + patched policy)

## After you are unblocked

Do **not** re-run `install.sh` until a safer (non-boot) version is published.
