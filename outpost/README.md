# Outpost

A universal, project-agnostic developer bootstrapper. Install it once, then run
`outpost` inside **any** repository to get set up: it detects the stack, installs
dependencies, initializes git submodules, and seeds env files from their
`*.example` templates. Idempotent and safe to re-run.

## Install

```sh
curl -fsSL https://outpost.overclock.studio/install.sh | sh
```

This drops a single self-contained script at `~/.outpost/bin/outpost` and adds it
to your PATH (via `~/.profile`, `~/.bashrc`, `~/.zshrc`, or fish config). Open a
new shell afterwards.

## Usage

```sh
outpost            # bootstrap the project in the current directory (alias: outpost up)
outpost doctor     # report which toolchains are installed
outpost self-update
outpost uninstall
outpost version
outpost help
```

### What `outpost up` does

Run from anywhere inside a repo (it finds the git top-level). For each stack it
recognizes, it runs the standard install — and skips everything it doesn't find:

| Detected                                   | Action                              |
|--------------------------------------------|-------------------------------------|
| `.gitmodules`                              | `git submodule update --init --recursive` |
| `package.json`                             | `bun`/`pnpm`/`yarn`/`npm` install (by lockfile) |
| `pyproject.toml` / `requirements.txt` / `Pipfile` | `poetry` / `uv` / `pipenv` / `pip` |
| `Cargo.toml`                               | `cargo fetch`                       |
| `go.mod`                                   | `go mod download`                   |
| `Gemfile`                                  | `bundle install`                    |
| `composer.json`                            | `composer install`                  |
| `Package.swift`                            | `swift package resolve`             |
| `*.example` / `*.sample` / `*.dist`        | copied to the real filename **if it doesn't exist yet** |

It never overwrites existing files, never prints or commits secrets, and never
deploys. If a stack is present but its toolchain is missing (e.g. a `Cargo.toml`
with no `cargo`), it warns and points you at `outpost doctor` instead of failing.

## Configuration

Environment variables (export before running the installer or the CLI):

| Var                      | Default                             | Meaning                                   |
|--------------------------|-------------------------------------|-------------------------------------------|
| `OUTPOST_BIN`            | `$HOME/.outpost/bin`                | Install directory                         |
| `OUTPOST_BASE_URL`       | `https://outpost.overclock.studio`  | Where the installer fetches `outpost`     |
| `OUTPOST_SRC`            | —                                   | Local file to install from (skips download) |
| `OUTPOST_NO_MODIFY_PATH` | `0`                                 | Set `1` to leave shell profiles untouched |
| `NO_COLOR`               | —                                   | Set to disable colored output             |

## Hosting

Serve two files at `OUTPOST_BASE_URL`:

- `install.sh` — the installer (this directory)
- `outpost`    — the CLI (this directory)

so that `https://outpost.overclock.studio/install.sh` and
`https://outpost.overclock.studio/outpost` return the raw scripts. Any static
host works (GitHub Pages, a Cloudflare Worker/Pages route, S3 + CDN, …).

## Uninstall

```sh
outpost uninstall
```

Removes `~/.outpost/bin/outpost`; remove the `# Added by the Outpost installer`
PATH line from your shell profile to finish.
