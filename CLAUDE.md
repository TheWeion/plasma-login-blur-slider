# CLAUDE.md

Guidance for Claude Code (and anyone else new to this repository).

## What this is

An add-on for KDE Plasma 6 that lets users choose how the wallpaper is blurred
behind the password prompt of the **login screen** (Plasma Login Manager) and
of the **lock screen** (kscreenlocker): a *Blur intensity* slider and a *Blur
style* choice (Standard, or Frosted glass) in each screen's settings page.
Plasma hardcodes this blur and has no setting for it.

Nothing of Plasma is patched or rebuilt. The package is a shell tool plus a
few QML files, `arch=(any)`, and has to keep working across Plasma updates.

## How it works

Wallpaper plugins are looked up in `XDG_DATA_DIRS`, and `/usr/local/share`
comes before `/usr/share`. `plasma-login-blur-slider sync` creates an
*overlay* plugin with the same id in `/usr/local/share/plasma/wallpapers/<id>/`
for each stock plugin. The overlay holds no copy of the stock code: its
`main.qml` and `config.qml` (from `wrappers/`) inherit from the stock files
through a generated `stock/qmldir`, and add:

| File | Runs in | Does |
|---|---|---|
| `qml/LoginBlurHook.qml` | `plasma-login-wallpaper`, `kscreenlocker_greet` | finds the screen's `FastBlur` of the wallpaper and rebinds its radius to `50 × intensity × factor`; for the frosted style creates `LoginBlurFrost` |
| `qml/LoginBlurFrost.qml` | same | Gaussian blur of the wallpaper, as a child of that `FastBlur`, faded in with the screen's `factor` |
| `qml/LoginBlurConfig.qml` | System Settings | adds the two rows to the *Login Screen* and *Screen Locking* settings pages, nowhere else |
| `qml/LoginBlurRow.qml`, `LoginBlurStyleRow.qml` | System Settings | the slider and the style choice |
| `qml/LoginBlurDebug*.qml` | `plasma-login-wallpaper` | diagnostics, only with `debug on` |

Settings are ordinary wallpaper settings (`LoginBlurIntensity` 0–100,
`LoginBlurStyle` `standard`/`frosted`, `LoginBlurDebug`), merged into each
overlay's copy of the plugin's `main.xml`. The login screen's are in
`/etc/plasmalogin.conf` (system-wide, written by a root helper), the lock
screen's in the user's `~/.config/kscreenlockerrc`. The two screens are
independent.

`plasma-login-blur-slider.in` is the tool (a template: `@VERSION@` and
`@DATADIR@` are filled in at install time). Besides `sync`/`remove` it has
`status`, `get`/`set`/`style` (with `--lock` for the lock screen),
`login-compositor`, `debug` and `report`.

Third-party "blur every window" compositor effects (Better Blur DX and its
relatives) blur the whole login screen regardless of our setting. `sync`, and
a systemd drop-in that runs `login-compositor` before the login screen's KWin
starts, switch them off in the *login user's* `kwinrc` only, record what was
switched off in a `[plasma-login-blur-slider]` group there, and `remove` puts
exactly that back.

## Layout

```
plasma-login-blur-slider.in      the tool (bash, template)
qml/                             QML copied into every overlay (as plmblur/)
wrappers/                        main.qml / config.qml of every overlay
packaging/                       pacman hook, systemd unit, compositor drop-in
PKGBUILD, *.install, Makefile    packaging and build
scripts/                         version.sh, dist.sh, lint-qml.sh, install-dev-deps.sh,
                                 release-preview.mjs
package.json, .releaserc.json    release and commit-message tooling (no project code)
tests/unit/                      bats tests of the tool, sandboxed
tests/integration/               real login screen and lock screen, headless
.github/workflows/               ci.yml (pull requests), release.yml (main)
```

## Commands

```sh
make check              # lint + unit tests; run before every commit
make lint               # shellcheck, qmllint, actionlint (lint-sh / lint-qml / lint-workflows)
make test               # unit tests (bats; uses fakeroot when not root)
make package            # dist/: source tarball + Arch package (needs makepkg)
make dist               # dist/: source tarball only
make release-preview    # what the commits since the last release would release (after npm ci)
sudo ./scripts/install-dev-deps.sh    # everything the above need, on Arch
```

`make test-integration PACKAGE=dist/….pkg.tar.zst` installs the package and
drives the real login screen and lock screen. It rewrites
`/etc/plasmalogin.conf` and the login user's settings and creates a user:
**containers and VMs only**. It refuses to run without
`PLBS_ALLOW_SYSTEM_TESTS=1`. CI runs it; do not run it on a developer machine.

`make lint-qml` and the integration tests need an Arch system with Plasma
installed. `make lint-sh` and `make test` run anywhere with shellcheck, bats
and fakeroot (tests that need `kreadconfig6`/`kwriteconfig6` skip without
them).

## Things that must stay true

- **Standard at 100 % is stock.** With default settings the login screen and
  lock screen must look exactly as they do without the package, pixel for
  pixel. Do not "improve" the default path.
- **Never break a login or lock screen.** Every failure has to end in stock
  behaviour: the hook does nothing if the scene is not what it expects, the
  frosted style falls back to standard, the drop-in's command is prefixed with
  `-` and wrapped in `timeout`. Treat anything that can throw at start-up in
  those processes as a release blocker.
- **The hook acts in two processes only**, recognised by
  `Qt.application.name`. The desktop loads the same overlays and must be
  unaffected, including its wallpaper settings dialog.
- **The hook is a property, not a child.** `WallpaperItem` replaces its
  children when a derived component declares any, so a child object in
  `wrappers/main.qml` would wipe out the stock wallpaper.
- **`stock/qmldir` uses a relative path.** KPackage canonicalises paths and
  rejects files outside the package directory otherwise.
- **Settings pages are recognised by their API**, not by name
  (`LoginBlurConfig.qml`). The Screen Locking module creates each page twice,
  first a throw-away instance: that one must not add rows. Both modules save
  only non-default values, so "absent" means default everywhere.
- **Only directories carrying our marker file are ever deleted** (`remove`,
  `sync`). Foreign directories in the overlay root are left alone.
- **`remove` restores everything**, including the compositor effects that were
  switched off. Uninstalling must leave no trace except settings entries that
  Plasma ignores.
- **The tool runs under `set -euo pipefail`.** A pipeline whose first command
  can fail (`getent … | cut …`) aborts the script; that has bitten once
  (`status` and `remove` without a login user). Add `|| true` where failure is
  an answer, and cover it with a unit test.
- **Frosted glass is measured, not eyeballed**: a Gaussian blur with a
  standard deviation of 0.64 px per percent (64 px at 100 %, which matches
  KWin's blur at strength 12; the stock blur is about 14.5 px). It blurs the
  picture as it is on screen, including the window background behind
  translucent wallpapers.

## Testing changes

- Tool logic: add or extend a bats test in `tests/unit/`. The helpers build a
  throw-away system per test; nothing real is touched.
- QML: `make lint-qml` catches syntax, type and import mistakes, but not
  misspelt identifiers (the `unqualified` check is off because of `i18nd()`
  and host-provided ids). Those surface as `ReferenceError` at run time, which
  the integration tests grep the logs for.
- Anything visual (pixel-identity with stock, how the blur looks, the settings
  pages) is not automated. It was verified by hand in a headless session with
  screenshots; say so in the pull request when a change needs it again, and
  ask for a test on real hardware. Everything so far was tested with software
  rendering.
- The integration tests are log-based: they check that the hook reports the
  configured blur and that the process survives, not what the screen looks
  like.

## Versions, commits, releases

- **Do not write version numbers anywhere.** The version is the latest
  `vX.Y.Z` tag; `scripts/version.sh` derives it. `pkgver=0.0.0` in `PKGBUILD`
  is a placeholder that `pkgver()` replaces at build time; never commit a
  changed `pkgver`.
- **Commit messages follow Conventional Commits** and decide the release:
  `fix:` patch, `feat:` minor, `!`/`BREAKING CHANGE:` major;
  `docs:`, `test:`, `ci:`, `build:`, `refactor:`, `style:`, `chore:` release
  nothing. Use `fix`/`feat` only for changes users of the package will notice.
  CI lints every commit and the pull request title, and its summary shows
  what merging would release (`make release-preview` does the same locally).
- A body line that begins with "breaking change", in any case, is read as a
  breaking change, even in the middle of a wrapped sentence. Reword it.
- Scopes in use: `hook`, `frost`, `settings`, `lock`, `cli`, `compositor`,
  `debug`, `build`, `ci`, `readme`.
- Work on a branch, open a pull request. CI builds and tests it and attaches
  the package. Merging to `main` runs the release workflow, which tags and
  publishes if the commits call for it. Nothing is committed back to `main`.

## Style

- Shell: bash, 4 spaces, shellcheck-clean, quoted expansions, `local` for
  every function variable. User-facing messages are plain sentences.
- QML: 4 spaces, KDE conventions. Comments explain why, especially where the
  code leans on how Plasma is built.
- Documentation and messages: plain and specific, no marketing words. The
  README is written for users, CONTRIBUTING.md for developers.
