# uppy
shell script that picks the distro updates, removes unused packages, debloats new installs, installs useful packages, sets up nfs and iscsi shares automatically
the original script is finalized and working 100% but has been marked as depricated and will no longer be updated. the nfs, iscsi and cifs shares feature has been removed from the appimage version of uppy and has been forked into its own appimage called mounty
the new version of uppy is an appimage with accompanying source code


# UPPY 4.1.0 — AppImage source

UPPY is a graphical Linux updater, maintenance and software-setup utility for
Arch-based, Fedora-based and Debian-based systems. This source tree contains
everything needed to build the AppImage yourself.

The AppImage bundles the Qt interface, Python runtime and UPPY Bash backend. It
uses the package managers already installed on the host, so Pacman, DNF, APT,
Flatpak and Snap always operate on the real system.

## Highlights

- Focused five-page interface: Overview, Setup, Apps, Output and About.
- Preview-first workflow with no administrator prompt for previews.
- PolicyKit authentication only when a system-changing task is applied.
- Native package and system-wide Flatpak updates.
- Optional orphan removal, cache cleanup and unused Flatpak cleanup.
- Workstation and gaming setup profiles.
- Name-only editors for native packages, Flatpak IDs, Snaps and removal targets.
- Saved-entry counts, unsaved-change feedback and discard protection.
- Live command output, rotating GUI log and reviewed confirmation before changes.

## Safety boundaries

The interface and backend both enforce these rules:

- Package and application values must be single validated names or IDs.
- User values are passed as separate process arguments, never as shell code.
- Preview commands include `--dry-run` and run without elevated privileges.
- Changes require a reviewed confirmation before PolicyKit authentication.
- Package removals are shown before execution.
- Flatpaks are managed explicitly in system-wide scope.

## Supported systems

- Arch Linux, CachyOS, EndeavourOS and Manjaro
- Fedora and Nobara
- Debian, Ubuntu and compatible Debian-based systems

The build supports `x86_64` and `aarch64`. Build on each architecture you plan
to distribute. For the widest compatibility, build on the oldest Linux base
you intend to support because PyInstaller uses the builder's glibc baseline.

## Build prerequisites

You need Python 3.10–3.14, Python virtual-environment support, `pip`, `binutils`,
`curl` or `wget`, and normal core command-line tools. Do not build as root.

Arch/CachyOS:

```bash
sudo pacman -S --needed python python-pip binutils curl
```

Fedora/Nobara:

```bash
sudo dnf install python3 python3-pip binutils curl
```

Debian/Ubuntu:

```bash
sudo apt install python3 python3-venv python3-pip binutils curl
```

`appimagetool` is downloaded into the private `.build` directory when it is not
already installed. Set `APPIMAGETOOL=/absolute/path/to/appimagetool` to use your
own copy, or set `NO_DOWNLOAD=1` to prohibit the download.

## Build the AppImage

```bash
chmod +x build-appimage.sh run-from-source.sh scripts/*.sh scripts/uppy-privileged
./build-appimage.sh
```

Output:

```text
dist-appimage/UPPY-4.1.0-<architecture>.AppImage
```

The build script runs source checks and unit tests before packaging, then prints
the SHA-256 digest of the completed AppImage.

Run the result:

```bash
chmod +x dist-appimage/UPPY-4.1.0-x86_64.AppImage
./dist-appimage/UPPY-4.1.0-x86_64.AppImage
```

PolicyKit's `pkexec` command must be available on the target system for actions
that make system changes. Previews, reports, managed-software lists and backups
do not need it.

## Run directly from source

```bash
./run-from-source.sh
```

This creates `.venv`, installs the GUI dependency and launches the same
interface used in the AppImage.

## App lists and settings

UPPY stores its user-editable app lists at:

```text
~/.config/uppy/config.json
```

The file is written atomically with mode `0600`. Existing 4.0 settings migrate
automatically; only supported application-list fields are retained.

Enter one exact name per line:

- System packages use the detected distribution's native package manager.
- Flatpak application IDs install system-wide from Flathub.
- Snap names require an existing host `snap` command.
- Removal names extend the distribution-specific bloat-removal list.

Saving a name does not install or remove it. Use Preview first, then select the
corresponding Install or Remove action.

## Build controls

| Variable | Purpose |
| --- | --- |
| `PYTHON` | Python interpreter used to build. Default: `python3`. |
| `UPPY_BUILD_DIR` | Private build directory. Default: `.build`. |
| `UPPY_OUTPUT_DIR` | AppImage output directory. Default: `dist-appimage`. |
| `APPIMAGETOOL` | Absolute path to an existing `appimagetool`. |
| `NO_DOWNLOAD=1` | Refuse to download `appimagetool`. |
| `UPPY_VENV_DIR` | Virtual environment used by `run-from-source.sh`. |

## Project layout

```text
src/main.py                 Qt interface
src/uppy_core.py            Validated settings and command construction
src/uppy-backend.sh         UPPY 4.1.0 host backend
scripts/uppy-privileged     Minimal PolicyKit entry point
scripts/check-source.sh     Source and backend validation
packaging/                  AppRun, desktop, icon and AppStream metadata
tests/                      Standard-library unit tests
build-appimage.sh           AppDir and AppImage assembly
run-from-source.sh          Development launcher
```

## Logs and backups

- GUI output: `~/.local/state/uppy/gui.log`
- Privileged backend: `/var/log/uppy.log`
- Package/configuration backups: `~/uppy-backups/<timestamp>`

The GUI log rotates to `gui.log.old` after approximately 2 MB.

## License

UPPY is released under the MIT License. See [LICENSE](LICENSE).
Bundled build dependencies retain their own licenses; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
