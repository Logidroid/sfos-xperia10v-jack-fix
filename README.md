# sfos-xperia10v-jack-fix

> ## ⚠️ CRITICAL WARNING — DO NOT INSTALL (for now)
>
> The **persistent PulseAudio systemd override** in this workaround has caused
> an **infinite loading spinner after entering the security code** on at least
> one Xperia 10 V (Sailfish OS 5.1.0.11). The jack worked until reboot; after
> reboot the UI session never finishes starting.
>
> **Do not run `./install.sh` until this is redesigned.**  
> If you already installed it and are stuck, see [RECOVERY.md](RECOVERY.md).

---

Workaround (experimental) for the headphone jack on the official **Sailfish OS**
port for **Sony Xperia 10 V** (`pdx235` / XQ-DC54 and siblings).

On the Jolla port, PulseAudio never exposes `output-wired_headset` /
`output-wired_headphone` because `/vendor/etc/primary_audio_policy_configuration.xml`
omits wired devices — even though the kernel detects the jack and the HAL has
headphone mixer paths.

### What broke the session

`install.sh` forced Pulse to start with a **custom** `default_sailfish.pa` via:

`~/.config/systemd/user/pulseaudio.service.d/jack-fix.conf`

If that config fails or hangs at user-session start (after unlock), **lipstick**
never comes up → infinite loading after the security code.

A safer approach (runtime-only `pactl load-module …`, no boot override) is needed
before this repo should be used again.

## Recovery

See **[RECOVERY.md](RECOVERY.md)** (SSH uninstall if possible, otherwise Sailfish
reflash / factory reset that clears `/home`).

## Old install steps (DISABLED — unsafe)

<details>
<summary>Previous instructions (do not use)</summary>

```sh
chmod +x install.sh uninstall.sh scripts/*
./install.sh   # UNSAFE until fixed
```

Uninstall (only if the phone still boots to UI or you have SSH):

```sh
./uninstall.sh
```

</details>

## How it was supposed to work

| Layer | Stock Jolla port | After this fix |
|--------|------------------|----------------|
| Kernel jack detect | OK | OK |
| HAL / mixer `headphones` | Present | Present |
| Audio policy XML | No `WIRED_*` devices | Patched copy in `$HOME` |
| Pulse `module-droid-card` | No wired ports | Ports created |
| Routing | Speaker only | Wired when selected |

## References

- [Forum: Feedback on Xperia 10 V](https://forum.sailfishos.org/t/feedback-on-xperia-10-v/20114)
- [Forum: Audio state 10 IV/V on 5.1](https://forum.sailfishos.org/t/xperia-10-iv-and-v-current-state-of-audio-as-of-5-1-3-5mm-jack-stereo-speakers/30511)
- [pulseaudio-modules-droid](https://github.com/mer-hybris/pulseaudio-modules-droid)

## Licence

MIT — see [LICENSE](LICENSE).
