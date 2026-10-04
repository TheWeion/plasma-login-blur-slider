# plasma-login-blur-slider

Adds a **Blur intensity** slider to *System Settings → Login Screen →
Configure Appearance…*, so you can choose how strongly Plasma Login Manager
blurs the wallpaper behind the login prompt — from 0 % (no blur) to 100 %
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

## Remove

    sudo pacman -R plasma-login-blur-slider

(or `sudo make uninstall`). This restores the stock behaviour completely. The
leftover `LoginBlurIntensity=` line in `/etc/plasmalogin.conf` is ignored by
Plasma and disappears the next time you press *Apply* in the Login Screen
settings.

If wallpapers ever misbehave and you suspect this package, this brings the
stock wallpaper plugins back immediately, without uninstalling anything:

    sudo plasma-login-blur-slider remove

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
it behaves exactly like the stock plugin.

Everything the package creates outside its own files is in
`/usr/local/share/plasma/wallpapers/`, one directory per wallpaper type, each
marked with a `.plasma-login-blur-slider` file. Directories there that it did
not create are never touched.

## Good to know

* **Only the blur changes.** The login screen also tones the wallpaper's
  colours down a little so the text stays readable; that stays as it is, even
  at 0 %.
* The value is stored with the settings of the chosen wallpaper type. When
  you switch the type in the Login Screen settings, the slider keeps its
  position.
* The slider moves in steps of 5 %; `set` accepts any whole number from 0 to
  100.
* Wallpaper types are overlaid only if Plasma Login Manager offers them and
  they are installed system-wide: `org.kde.image`, `org.kde.color`,
  `org.kde.potd`, `org.kde.haenau`, `org.kde.hunyango`, `org.kde.tiled`,
  `online.knowmad.shaderwallpaper`. To change the list, set `PLUGINS="…"` in
  `/etc/plasma-login-blur-slider.conf` and run `sudo plasma-login-blur-slider
  sync`.
* `/usr/local/share` has to come before `/usr/share` in `XDG_DATA_DIRS`,
  which is the default. `plasma-login-blur-slider status` checks this for the
  session it is run in.
* The hook relies on how Plasma Login Manager builds its wallpaper scene, and
  the slider on how its settings page is laid out. If a future release
  changes either, the affected part quietly does nothing and you are back to
  stock behaviour; the login screen itself is not affected.

## Tested with

Plasma Login Manager 6.7.5 (Plasma 6.7.5, KDE Frameworks 6.30, Qt 6.11) on
Arch Linux packages.

## License

GPL-3.0-or-later
