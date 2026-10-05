# plasma-login-blur-slider

Adds a **Blur intensity** slider to *System Settings → Login Screen →
Configure Appearance…*, so you can choose how strongly Plasma Login Manager
blurs the wallpaper behind the login prompt: from 0 % (no blur) to 100 %
(the stock look).

Plasma Login Manager itself is not patched, replaced or rebuilt, and nothing
is compiled, so the package keeps working across Plasma updates.

## Install

### Garuda, CachyOS, EndeavourOS, Manjaro, Arch

Install the prebuilt package:

    sudo pacman -U plasma-login-blur-slider-1.0.0-1-any.pkg.tar.zst

or build it yourself from this directory:

    makepkg -si

That is all. A pacman hook keeps things in step whenever Plasma's wallpaper
plugins are updated.

### Other distributions

    sudo make install install-systemd-unit
    sudo systemctl enable --now plasma-login-blur-slider.service

The service runs `plasma-login-blur-slider sync` now and at every boot, which
is what the pacman hook does on Arch-based systems.

## Use

Open *System Settings → Login Screen → Configure Appearance…*, move the
**Blur intensity** slider and press *Apply*. The change shows the next time
the login screen starts (log out or reboot).

The same from a terminal:

    plasma-login-blur-slider get          # prints 0-100
    sudo plasma-login-blur-slider set 35
    plasma-login-blur-slider status       # what is installed, current value

Each time the login screen starts, its wallpaper process logs one line such
as `plasma-login-blur-slider: login wallpaper blur set to 35%`, which is a
quick way to confirm the setting was picked up:

    journalctl -b | grep plasma-login-blur-slider

## Remove

    sudo pacman -R plasma-login-blur-slider

(or `sudo make uninstall`). This restores the stock behaviour completely. A
leftover `LoginBlurIntensity=` line in `/etc/plasmalogin.conf` is ignored by
Plasma and disappears the next time you press *Apply* in the Login Screen
settings.

If wallpapers ever misbehave and you suspect this package, this brings the
stock wallpaper plugins back immediately, without uninstalling anything:

    sudo plasma-login-blur-slider remove

(`sudo plasma-login-blur-slider sync` turns it back on.)

## If it does not work

    sudo plasma-login-blur-slider debug on

then restart, and at the login screen wait ten seconds, move the mouse so the
password prompt appears, and leave everything alone for twenty seconds until
the prompt is gone again. Log in and run

    sudo plasma-login-blur-slider report

This writes a folder `plasma-login-blur-report` to your home directory. It
contains `report.txt` (versions, the login screen's configuration, what the
login wallpaper process and the compositor logged) and a few screenshots the
wallpaper process took of its own output. Together they show whether the blur
you see is the one this add-on controls or comes from somewhere else, for
example a compositor effect. `sudo plasma-login-blur-slider debug off`
switches the diagnostics off again.

## How it works

The login screen draws its wallpaper with an ordinary Plasma wallpaper plugin
(the same *Image*, *Plain Color*, … plugins the desktop uses), and the Login
Screen settings page embeds that plugin's own settings page. Plugins are
looked up in `/usr/local/share` before `/usr/share`.

`plasma-login-blur-slider sync` puts a small *overlay* plugin with the same
id into `/usr/local/share/plasma/wallpapers/<id>/`. The overlay contains no
copy of the stock plugin's code. Its `main.qml` and `config.qml` load the
stock files and add three things:

* a `LoginBlurIntensity` setting, saved by the Login Screen settings exactly
  like the wallpaper's other settings (in `/etc/plasmalogin.conf`);
* the slider, which is only created inside the Login Screen settings;
* a hook that scales the login screen's blur by that setting. It only acts
  inside Plasma Login Manager's wallpaper process.

The desktop and the lock screen find the same overlay plugins, but for them
they behave exactly like the stock plugins.

Everything the package creates outside its own files is in
`/usr/local/share/plasma/wallpapers/`, one directory per wallpaper type, each
marked with a `.plasma-login-blur-slider` file. Directories there that it did
not create are never touched.

## Good to know

* **Only the blur changes.** The login screen also adjusts the wallpaper's
  colours a little so the text stays readable; that stays as it is, even at
  0 %.
* The value is stored with the settings of the chosen wallpaper type. When
  you switch the type in the Login Screen settings, the slider keeps its
  position.
* The slider moves in steps of 5 %; `set` accepts any whole number from 0 to
  100.
* Wallpaper types are overlaid only if Plasma Login Manager offers them and
  they are installed system-wide: `org.kde.image`, `org.kde.color`,
  `org.kde.potd`, `org.kde.haenau`, `org.kde.hunyango`, `org.kde.tiled`,
  `online.knowmad.shaderwallpaper`. To change the list, set `PLUGINS="…"` in
  `/etc/plasma-login-blur-slider.conf` and run
  `sudo plasma-login-blur-slider sync`.
* `/usr/local/share` has to come before `/usr/share` in `XDG_DATA_DIRS`,
  which is the default. `plasma-login-blur-slider status` checks this for the
  session it is run in.
* Switching the wallpaper type in the Login Screen settings logs a few
  harmless warnings from Kirigami's FormLayout while the old slider row is
  removed.
* The hook relies on how Plasma Login Manager builds its wallpaper scene, and
  the slider on how its settings page is laid out. If a future release
  changes either, the affected part quietly does nothing and you are back to
  stock behaviour; the login screen itself is not affected.

## Tested with

Plasma Login Manager 6.7.5 from the Arch Linux packages (Plasma 6.7.5, KDE
Frameworks 6.30, Qt 6.11), with the Image, Plain Color, Picture of the Day,
Haenau, Hunyango and Tiled wallpaper types, including the desktop and the
lock screen, which have to keep behaving as before.

The wallpaper process and the settings module of Plasma Login Manager 6.6.6,
of the 6.8 beta and of the development branch (October 2026) were also run
against it, built from source on the same system.

## Files

    /usr/bin/plasma-login-blur-slider             the sync/remove/get/set/debug/report tool
    /usr/share/plasma-login-blur-slider/          QML the overlays are made from
    /usr/share/libalpm/hooks/plasma-login-blur-slider.hook    (Arch-based)
    /usr/lib/systemd/system/plasma-login-blur-slider.service  (other distros)
    /etc/plasma-login-blur-slider.conf            optional overrides

## License

GPL-3.0-or-later
