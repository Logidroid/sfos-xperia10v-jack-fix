# Recovery — infinite loading after security code

If you installed **v1** of this workaround and after reboot the phone stays on a
**spinner forever after the PIN/code**, the user session is stuck because Pulse
was started with a broken boot override:

`~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf`

**v2.2 does not create that file** (only a runtime drop-in under `/run`, wiped on
reboot). If you only ever installed v2.2 and still hang, remove the units below
anyway, then report it — that would be unexpected.

## 1) Prefer: SSH while the spinner is showing

After you enter the security code, `/home` is unlocked. If Wi‑Fi reconnects
(or USB developer networking works):

```sh
ssh -i ~/.ssh/qtc_id -o IdentitiesOnly=yes defaultuser@PHONE_IP
```

Then:

```sh
systemctl --user disable --now jack-audio-fix.timer 2>/dev/null || true
systemctl --user disable --now jack-audio-fix.service 2>/dev/null || true
rm -f ~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf
rm -f ~/.config/systemd/user/jack-audio-fix.service
rm -f ~/.config/systemd/user/jack-audio-fix.timer
rm -rf ~/audio-jack-fix
rm -f ~/bin/reload-droid-jack.sh ~/bin/apply-jack-policy.sh
systemctl --user daemon-reload
systemctl --user restart pulseaudio 2>/dev/null || true
# if still stuck:
devel-su reboot
```

Or run `./uninstall.sh` from a copy of this repo on the phone.

`172.28.172.1` only works with **USB Developer Mode** networking. A plain
“USB device detected” notification is **not** enough (no `usb0`).

## 2) No SSH: Jolla Recovery (keeps user data)

1. Force power off: **Power + Volume Up**.
2. Fastboot: phone off → hold **Volume Up** → plug USB → `fastboot devices`.
3. Boot/flash recovery from your Sailfish flash package, e.g.
   `fastboot flash boot_a hybris-recovery.img` then reboot into recovery.
4. Telnet to `10.42.66.66`, shell.
5. Unlock LUKS `/home` if encrypted, mount it, then delete:

```sh
rm -f /home/defaultuser/.config/systemd/user/pulseaudio.service.d/jack-fix.conf
rm -f /home/defaultuser/.config/systemd/user/jack-audio-fix.service
rm -f /home/defaultuser/.config/systemd/user/jack-audio-fix.timer
rm -rf /home/defaultuser/audio-jack-fix
sync
```

6. Restore real boot: `fastboot flash boot_a hybris-boot.img` then reboot.
   Do **not** run full `flash.sh` unless you accept wiping data.

## 3) Last resort: reflash with home wipe

Only if recovery deletion failed. Use the official flash package and accept
clearing device data so the drop-in is gone.

## Files that caused the v1 hang

- `~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf` ← critical
- (also remove) `jack-audio-fix.service` / `.timer`, `~/audio-jack-fix/`

## After you are unblocked

Reinstall **only** from current `master` (v2.2+: timer + runtime `/run` override,
never a persistent Pulse drop-in). Confirm
`~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf` does **not** exist
after `./install.sh`.
