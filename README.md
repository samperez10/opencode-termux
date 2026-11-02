# OpenCode for Termux

Automatic ARM64 Termux packages for the latest stable
[OpenCode](https://github.com/anomalyco/opencode) v2 release.

This community project verifies the official upstream ARM64 artifact, packages
it with a Termux launcher, and runs it through PRoot with Termux's glibc
runtime. The
installed command is simply `opencode`.

## Install

From ARM64 Termux:

```sh
pkg install -y curl
curl -fsSL https://github.com/samperez10/opencode-termux/releases/latest/download/install.sh | sh
```

Then run:

```sh
opencode
```

The installer:

- verifies that it is running in ARM64 Termux;
- installs `proot` and `glibc` from Termux repositories when needed;
- downloads the latest release from this repository;
- verifies its SHA-256 checksum before extraction;
- starts the downloaded binary once before activating it;
- installs the launcher as `$PREFIX/bin/opencode`.

Preview the selected release without changing the device:

```sh
curl -fsSL https://github.com/samperez10/opencode-termux/releases/latest/download/install.sh -o install-opencode.sh
sh install-opencode.sh --dry-run
```

## Updates

GitHub Actions checks the official OpenCode release feed every six hours. When
a new stable v2 release appears, the workflow:

1. downloads `opencode-linux-arm64.tar.gz` and upstream `SHA256SUMS`;
2. verifies the official checksum;
3. verifies that the executable targets AArch64;
4. packages the executable with the Termux launcher;
5. verifies the new package checksum and archive layout;
6. publishes a same-version release in this repository.

The launcher checks this repository once per day, including its first run. In
an interactive terminal it offers **Yes**, **Not now**, and **Skip this
version** choices. Non-interactive runs print the update command and continue.
Set
`OPENCODE_TERMUX_NO_UPDATE_CHECK=1` to disable that network check.

To update immediately, run the installer command again.

## Manual workflow runs

The **Sync latest OpenCode for Termux** workflow accepts:

- `opencode_version`: a specific v2 version such as `2.2.5`, or `latest`;
- `publish_release`: publish after validation, or only retain a workflow artifact.

Scheduled builds only publish versions that do not already have a release.
Failures stop before publication.

## Why PRoot and glibc?

Official OpenCode ARM64 releases target GNU/Linux. Android uses Bionic rather
than glibc, so the official executable cannot be launched directly by Termux.
The launcher binds Termux's glibc loader at `/lib` through PRoot while keeping
the upstream OpenCode executable unchanged. This is important because Bun uses
its executable path to spawn OpenCode's background server; launching only the
parent through `ld.so` breaks that child process.

The v2.2.5 artifact was verified on an ARM64 Termux device with the full TUI and
background server, in addition to `opencode --version` and `opencode --help`.

## Project layout

```text
.github/workflows/release.yml     scheduled verification and release workflow
install.sh                        checksum-verifying Termux installer
scripts/package-upstream-v2.sh    creates the Termux archive and launcher
```

## Scope

- Android/Termux on AArch64 only
- Current stable OpenCode v2 releases
- No silent application updates: the launcher reports an available update and
  the user reruns the installer

OpenCode itself is maintained by the
[OpenCode project](https://github.com/anomalyco/opencode). This repository only
provides Termux packaging and installation support.
