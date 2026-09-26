# sfos-xperia10v-jack-fix

Workaround for the **3.5 mm headphone jack** on the official **Sailfish OS** port for **Sony Xperia 10 V** (`pdx235` / XQ-DC54 and siblings).

On the Jolla port, PulseAudio never exposes `output-wired_headset` / `output-wired_headphone` because `/vendor/etc/primary_audio_policy_configuration.xml` omits wired devices — even though the kernel detects the jack and the HAL has headphone mixer paths.

This fix:

1. Copies the vendor audio policy into `~/audio-jack-fix/`
2. Patches it to declare wired headset/headphones (+ mic)
3. Starts user PulseAudio with that policy (systemd drop-in, **no root**)
4. Optionally selects the wired port when a jack is plugged

Validated on Sailfish OS **5.1.0.11** (Xperia 10 V).

> Community Lineage-based ports (e.g. zambezi) often already have a working jack. This targets the **official Jolla** image.

## Install (on the phone)

Developer Mode + SSH or Terminal:

```sh
# From a PC with the repo, or clone on-device if git is available:
cd sfos-xperia10v-jack-fix
chmod +x install.sh uninstall.sh scripts/*.sh
./install.sh
```

Plug headphones and play a sound. You should hear it in the headset.

## Uninstall

```sh
./uninstall.sh
```

## After a Sailfish update

Usually fine (user-space only). If audio breaks:

```sh
./uninstall.sh
# then re-run ./install.sh if the jack is still missing
```

If a future SFOS release already includes wired ports in vendor policy, uninstall this workaround.

## How it works

| Layer | Stock Jolla port | After this fix |
|--------|------------------|----------------|
| Kernel jack detect | OK | OK |
| HAL / mixer `headphones` | Present | Present |
| Audio policy XML | No `WIRED_*` devices | Patched copy in `$HOME` |
| Pulse `module-droid-card` | No wired ports | Ports created |
| Routing | Speaker only | Wired when selected |

## Limitations

- User override of Pulse config; not a vendor/HAL rewrite
- Auto-switch on plug may need a Pulse restart or re-run of `~/bin/reload-droid-jack.sh` in some cases
- Not tested on Xperia 10 IV official port (similar symptom — may work with the same approach)
- Does not replace a proper Jolla / community fix

## References

- [Forum: Feedback on Xperia 10 V](https://forum.sailfishos.org/t/feedback-on-xperia-10-v/20114)
- [Forum: Audio state 10 IV/V on 5.1](https://forum.sailfishos.org/t/xperia-10-iv-and-v-current-state-of-audio-as-of-5-1-3-5mm-jack-stereo-speakers/30511)
- [pulseaudio-modules-droid](https://github.com/mer-hybris/pulseaudio-modules-droid)

## Licence

MIT — see [LICENSE](LICENSE).
