# sfos-xperia10v-jack-fix

Workaround for the headphone jack on official **Sailfish OS** for **Sony Xperia 10 V**
(`pdx235` / XQ-DC54). May help Xperia 10 IV (same class of bug; not verified).

## Safety (read this)

**v1** overrode `pulseaudio.service` at boot (`jack-fix.conf`) and caused
**infinite loading after the security code**. That approach is **removed and purged**
by the installer.

**v2.2** (current):

| Layer | Behaviour |
|--------|-----------|
| Pulse at boot | **Stock** — no file under `~/.config/.../pulseaudio.service.d/` |
| When jack policy applies | **Timer ~25s**: runtime drop-in in `$XDG_RUNTIME_DIR` + restart Pulse |
| After reboot | `/run` is empty → stock Pulse again until timer |
| On apply failure | Remove runtime drop-in + restore stock Pulse |

Residual risks: brief mute after unlock while Pulse restarts; jack may still fail
(then stock audio remains).

**Mandatory:** after install, reboot once and confirm lock screen → home works.

If you installed v1 and cannot unlock past the spinner, see [RECOVERY.md](RECOVERY.md).

## Cause

Vendor `primary_audio_policy_configuration.xml` omits `AUDIO_DEVICE_OUT_WIRED_*`,
so Pulse never creates `output-wired_headset` / `output-wired_headphone`.

## Install (on the phone, UI working)

Developer Mode + SSH or Terminal:

```sh
cd sfos-xperia10v-jack-fix
chmod +x install.sh uninstall.sh scripts/*
./install.sh
```

Then **reboot once** and confirm the UI comes up. Only then rely on it.

Manual apply anytime (after UI is up):

```sh
~/bin/apply-jack-policy.sh
```

## Uninstall

```sh
./uninstall.sh
```

## Recovery (v1 brick / spinner after PIN)

[RECOVERY.md](RECOVERY.md) — delete at least:

- `~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf`  ← the real brick
- `~/.config/systemd/user/jack-audio-fix.service`
- `~/.config/systemd/user/jack-audio-fix.timer`
- `~/audio-jack-fix/`

## Licence

MIT — see [LICENSE](LICENSE).
