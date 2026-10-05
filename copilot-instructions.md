# Copilot instructions for plasma-login-blur-slider

An add-on for KDE Plasma 6: a *Blur intensity* slider and a *Blur style* choice (Standard or Frosted glass) for the wallpaper behind the password prompt of the login screen (Plasma Login Manager) and of the lock screen. It is a bash tool, `plasma-login-blur-slider.in`, plus QML in `qml/` and `wrappers/`, packaged for Arch-based systems. Nothing is compiled and nothing of Plasma is patched: the tool creates overlay wallpaper plugins in `/usr/local/share/plasma/wallpapers/` that inherit from the stock ones.

`CLAUDE.md` in the repository root explains the design at length. This file is its short form. Keep the two in agreement.

## Rules for every change, and what to check in a review

- **Default settings must look exactly like stock Plasma.** Standard style at 100 % is pixel-identical to an unmodified login and lock screen. Leave that path alone.
- **A failure must end in stock behaviour, never in a broken login or lock screen.** The QML hook does nothing when the scene is not what it expects, frosted falls back to standard, and the systemd drop-in keeps its `-` prefix and its `timeout`. Flag anything that can throw or block when `plasma-login-wallpaper` or `kscreenlocker_greet` starts.
- **The hook acts in those two processes only** (it checks `Qt.application.name`). The desktop loads the same overlays and must not change.
- **In `wrappers/main.qml` the hook is held in a property, never declared as a child.** A child object would replace the stock wallpaper's own children.
- **The settings rows appear only in the Login Screen and Screen Locking settings.** `qml/LoginBlurConfig.qml` recognises those pages by their API. Screen Locking creates each page twice, and the throw-away first instance must not add rows.
- **`sync` and `remove` delete only directories carrying the tool's marker file**, and `remove` undoes everything `sync` did.
- **The tool runs under `set -euo pipefail`.** A pipeline whose first command may fail (`getent … | cut …`) aborts it. Where failure is an answer, add `|| true`.
- **A change to the tool's logic comes with a bats test** in `tests/unit/`.
- **Never write a version number.** The version is the latest `vX.Y.Z` git tag, read by `scripts/version.sh`. `pkgver=0.0.0` in `PKGBUILD` is a placeholder; a changed one must not be committed. Never create a tag or a release.
- **Commit messages and pull request titles follow Conventional Commits**, with a lower-case subject and no full stop: `fix(lock): keep the blur when the prompt is reopened`. They decide the releases: `fix` gives a patch, `feat` a minor, `!` or a `BREAKING CHANGE:` footer a major release, and `docs`, `test`, `ci`, `build`, `refactor`, `style` and `chore` give none. Use `fix` and `feat` only for what users of the package notice. Do not begin a body line with "breaking change" unless it is one.
- **Every file states its copyright and licence** (REUSE, GPL-3.0-or-later). A new file that can hold a comment starts, after any shebang and in its own comment syntax, with the lines `SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors` and `SPDX-License-Identifier: GPL-3.0-or-later`. One that cannot (JSON, fixtures) is added to `REUSE.toml`. Never edit `LICENSE`, `LICENSES/` or an existing copyright or licence line, and never bring in another licence without saying so.
- **Do not try a change on the real system.** `sudo make install`, and the tool's `sync`, `remove`, `set`, `style` and `login-compositor`, change the login screen of the machine they run on. The unit tests give every command a throw-away system instead.
- Shell is bash with 4 spaces, shellcheck-clean, quoted expansions and `local` in functions. QML uses 4 spaces, and comments say why. Messages and documentation are plain sentences.

## Checking a change

Run what applies before proposing a change. Each of these was run on Ubuntu 24.04 and on Arch.

| Command | What it checks | Needs |
|---|---|---|
| `make lint-sh` | shellcheck on the tool and every script | shellcheck |
| `make test` | 48 unit tests, each in a throw-away directory | bats, fakeroot |
| `make lint-reuse` | copyright and licence of every file | `reuse` 4 or later |
| `make lint-workflows` | the GitHub workflows | actionlint |
| `npx commitlint --from origin/main` | the commit messages | `npm ci` |
| `make release-preview` | what the commits would release | `npm ci` |

On Ubuntu, which is what Copilot's cloud agent runs on by default:

```sh
sudo apt-get install -y shellcheck bats fakeroot
pipx install reuse
npm ci
```

Without KDE Frameworks installed, 16 of the 48 unit tests are skipped, because they need `kreadconfig6` and `kwriteconfig6`. That is expected, and CI runs them.

These need an Arch system with Plasma. Leave them to CI:

- `make lint-qml` (qmllint with the KDE QML modules) and `make package` (makepkg). `make check` and `make lint` include `lint-qml`, so they only pass completely on Arch.
- `make test-integration` installs the package and drives the real login screen and lock screen. It rewrites `/etc/plasmalogin.conf` and creates a user. **Never run it outside CI**, and never set `PLBS_ALLOW_SYSTEM_TESTS`, which it insists on.

qmllint does not catch a misspelt identifier in QML; that shows up as a `ReferenceError` in the logs the integration tests read. Nothing automated checks what the screens look like. If a change can affect that, say so in the pull request and ask for a test on a real machine.

## Layout

```
plasma-login-blur-slider.in      the tool; a template, @VERSION@ and @DATADIR@ are filled in at install time
qml/LoginBlurHook.qml            runs in the login and lock screen: rebinds the blur radius, creates the frost layer
qml/LoginBlurFrost.qml           the frosted glass blur (Gaussian, 0.64 px of standard deviation per percent)
qml/LoginBlurConfig.qml          runs in System Settings: adds the two rows, with LoginBlurRow and LoginBlurStyleRow
qml/LoginBlurDebug*.qml          diagnostics, loaded only after "debug on"
wrappers/                        main.qml and config.qml of every overlay; they inherit from the stock plugin
packaging/                       pacman hook, systemd unit, drop-in for the login screen's compositor
Makefile, PKGBUILD, *.install    build and Arch packaging
scripts/                         version.sh, dist.sh, lint-qml.sh, install-dev-deps.sh, release-preview.mjs
tests/unit/                      bats tests; helpers.bash builds the throw-away system
tests/integration/               headless tests of the installed package (CI only)
REUSE.toml, LICENSES/, LICENSE   licensing
package.json, .releaserc.json    commit-message and release tooling; the project itself has no Node.js code
```

The settings are ordinary wallpaper settings: `LoginBlurIntensity` (0 to 100), `LoginBlurStyle` (`standard` or `frosted`) and `LoginBlurDebug`. The login screen's are in `/etc/plasmalogin.conf`, the lock screen's in the user's `~/.config/kscreenlockerrc`, and the two are independent. Both settings modules save only values that differ from the default, so an absent entry means the default.

## CI and releases

- Every pull request runs `.github/workflows/ci.yml`, and its three jobs must pass: **Commit messages** (commits and title, and a preview of what merging would release), **Lint**, and **Build and test** (in an Arch container: unit tests, the package, the integration tests). The built package is attached to the run.
- Every push to `main` runs `.github/workflows/release.yml`: the same jobs, then semantic-release, which tags and publishes a release if the commits since the last tag contain a `fix` or a `feat`. Nothing is committed back to `main`.
- Commit scopes in use: `hook`, `frost`, `settings`, `lock`, `cli`, `compositor`, `debug`, `build`, `ci`, `readme`.
- In `package.json`, `conventional-changelog-conventionalcommits` stays at version 9 and `conventional-commits-filter` stays listed. Both are there for a reason given in `CONTRIBUTING.md`.

Trust these instructions. Search the repository only where they are incomplete or turn out to be wrong.
