# sfos-xperia10v-jack-fix

Workaround for the headphone jack on official **Sailfish OS** for **Sony Xperia 10 V**
(`pdx235` / XQ-DC54). May help Xperia 10 IV (same class of bug; not verified).

## Safety (read this)

**v1** overrode `pulseaudio.service` at boot and caused **infinite loading after the
security code** on reboot. That approach is **removed**.

**v2** (current):

- Leaves Pulse boot config **stock**
- Applies the patched audio policy **only after `lipstick` (UI) is up**
- Still reboot-test before daily use

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

Then **reboot once** and confirm the lock screen → home works. Only then rely on it.

Manual apply anytime:

```sh
~/bin/apply-jack-policy.sh
```

## Uninstall

```sh
./uninstall.sh
```

## Recovery (v1 brick / spinner after PIN)

[RECOVERY.md](RECOVERY.md) — delete:

- `~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf`
- `~/.config/systemd/user/jack-audio-fix.service`
- `~/audio-jack-fix/`

## Licence

MIT — see [LICENSE](LICENSE).
