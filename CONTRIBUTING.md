# Contributing

## Setting up

The project is a bash script and some QML; there is nothing to compile.
Development is easiest on an Arch-based system (Arch, Garuda, CachyOS,
EndeavourOS, Manjaro), because the package is built with `makepkg`:

    sudo ./scripts/install-dev-deps.sh     # lint, build, test and release tools
    npm ci                                 # commit-message and release tooling

Elsewhere you can still work on the tool and run its unit tests with
`shellcheck`, `bats`, `fakeroot`, `git` and `make` installed.

## Everyday commands

    make check        lint and unit tests; run this before committing
    make lint         shellcheck, qmllint, actionlint and the REUSE check
    make test         unit tests
    make package      source tarball and Arch package, in dist/
    make dist         source tarball only

The unit tests run the tool against a throw-away directory tree and are safe
anywhere. `sync` and `remove` insist on root, so the tests run under
`fakeroot` when you are not root.

The integration tests (`make test-integration PACKAGE=dist/….pkg.tar.zst`)
install the package and drive the real login screen and lock screen in a
headless session. They rewrite `/etc/plasmalogin.conf`, the login user's
compositor settings and create a test user, so they only run with
`PLBS_ALLOW_SYSTEM_TESTS=1` set, and only belong in a container or a virtual
machine. CI runs them for every pull request.

What no test covers is what the screens look like. If a change can affect
that, try the package from the pull request on a real machine and say in the
pull request what you checked.

## Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org/).
This is not cosmetic: the release workflow decides from them whether to
release and which version number comes next.

| Type | Use it for | Release |
|---|---|---|
| `fix:` | a bug fix users of the package will notice | patch (1.0.0 → 1.0.1) |
| `feat:` | something new for users | minor (1.0.0 → 1.1.0) |
| `feat!:` / `fix!:`, or a `BREAKING CHANGE:` footer | a change users have to react to | major (1.0.0 → 2.0.0) |
| `perf:` | the same behaviour, faster | patch |
| `docs:` `test:` `ci:` `build:` `refactor:` `style:` `chore:` | everything users do not notice | none |

Write the subject in lower case, in the imperative, without a full stop:
`fix(lock): keep the blur when the prompt is reopened`. Scopes in use are
`hook`, `frost`, `settings`, `lock`, `cli`, `compositor`, `debug`, `build`,
`ci` and `readme`.

`npx commitlint --from origin/main` checks your branch the way CI will, and
`make release-preview` shows what the commits since the last release would
release.

One trap: a line in the body that begins with "breaking change" is taken for
a breaking change, whatever the case and even if it is the middle of a wrapped
sentence. Break the line somewhere else.

## Licensing

The project is licensed under GPL-3.0-or-later and follows the
[REUSE](https://reuse.software) specification, which means that every file
says who holds its copyright and under which licence it is. `make lint-reuse`
checks that with the `reuse` tool (`pacman -S reuse`, or `pipx install reuse`),
and CI runs it as part of **Lint**.

A new file needs one of two things:

- If it can hold a comment, it starts with these two lines, in its own comment
  syntax and after the shebang if there is one:

      # SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
      # SPDX-License-Identifier: GPL-3.0-or-later

  Copy them from a neighbouring file, or let the tool write them:

      reuse annotate --copyright "plasma-login-blur-slider contributors" \
          --license GPL-3.0-or-later path/to/file

- If it cannot (JSON, a test fixture, a generated file), add its path to
  `REUSE.toml`. Markdown files are covered there already.

The licence text is in the repository twice: `LICENSE`, where people and
GitHub look for it, and `LICENSES/GPL-3.0-or-later.txt`, where REUSE requires
it. They are the same, unmodified text, and the lint fails if they ever differ.

If you bring in code from elsewhere, keep its copyright and licence notices,
and raise it in the pull request if its licence is not GPL-3.0-or-later.

## Pull requests

1. Branch from `main`, commit, push, open a pull request. Give it a
   Conventional Commits title: if it is squashed, the title becomes the commit
   message.
2. CI runs three jobs, and all three have to pass:
   - **Commit messages**: every commit and the title; its summary also says
     what merging would release;
   - **Lint**: shellcheck, qmllint, actionlint, and the REUSE check;
   - **Build and test**: unit tests, the package, and the integration tests
     with that package installed.
3. The **Build and test** job attaches the built package to the run
   (*Summary → Artifacts*). Reviewers can download it and install it with
   `sudo pacman -U`; the run's summary shows the command and the checksums. A
   pull request build is versioned after the last release, for example
   `1.2.0.r3.gabc1234`, so it installs over a release and the next release
   installs over it.
4. Merge when it is green and approved. Squash and rebase merges both keep the
   history readable for the release notes.

## Releases

Nobody makes a release by hand, and nobody edits a version number.

Every push to `main` runs the release workflow. It runs the CI jobs again and
then [semantic-release](https://semantic-release.gitbook.io/), which looks at
the commits since the last `vX.Y.Z` tag. If there is a `fix` or `feat` among
them it works out the next version, builds the package and the source tarball
with that version, creates the tag and publishes a GitHub release with the
files, their checksums and release notes written from the commit messages. If
there is not, nothing happens.

The version is not stored in the repository. `scripts/version.sh` derives it
from the tag (in a clone), from the `VERSION` file (in a release tarball) or
from GitHub's archive metadata, and the Makefile and the `PKGBUILD` ask it.
The `pkgver=0.0.0` line in `PKGBUILD` is a placeholder; do not commit a
changed one.

To see what the next release would be without making it:

    make release-preview

Two things about the tooling in `package.json`:
`conventional-changelog-conventionalcommits` is held at version 9, because the
notes generator that comes with semantic-release 25 cannot render the
templates of version 10; and `conventional-commits-filter` is listed only to
settle a peer dependency on which commitlint and semantic-release disagree.

## Repository settings

These cannot be kept in the repository and have to be set once on GitHub:

- **Branch protection (or a ruleset) for `main`**: require a pull request, and
  require the status checks `Commit messages`, `Lint` and `Build and test`.
- **Actions → General → Workflow permissions**: the default read-only token is
  enough; the release job asks for `contents: write` itself.
- Set `url=` in `PKGBUILD` to the repository's address.
