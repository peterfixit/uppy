#!/usr/bin/env bash
# UPPY 2.0.1 single-file rebuilt build: 2026-07-06T00-unique
set -Eeuo pipefail

UPPY_VERSION="2.0.1"

# Runtime flags are declared before functions so they are available everywhere.
DRY_RUN=false
VERBOSE=false
LOG_FILE=""

run_cmd() {
    local cmd=("$@")

    if [[ ${#cmd[@]} -eq 0 ]]; then
        return 0
    fi

    if $VERBOSE; then
        printf '[cmd]'
        printf ' %q' "${cmd[@]}"
        printf '\n'
    fi

    if [[ -n "$LOG_FILE" ]]; then
        {
            printf '[%s] CMD:' "$(date '+%Y-%m-%d %H:%M:%S')"
            printf ' %q' "${cmd[@]}"
            printf '\n'
        } >> "$LOG_FILE" 2>/dev/null || true
    fi

    if $DRY_RUN; then
        printf '[dry-run]'
        printf ' %q' "${cmd[@]}"
        printf '\n'
        return 0
    fi

    "${cmd[@]}"
}

if [[ $EUID -eq 0 ]]; then
    run_sudo() { run_cmd "$@"; }
else
    run_sudo() { run_cmd sudo "$@"; }
fi

AUTO_SKIP_OPTIONAL=false
AUTO_REBOOT=false
ASSUME_YES=false
QUIET_MODE=false
RUN_ONLY=""
UPPY_UPDATE_URL="${UPPY_UPDATE_URL:-}"

show_help() {
    cat <<EOF
UPPY v${UPPY_VERSION}

Usage:
  uppy [OPTIONS]

Options:
  -h, --help             Show this help message and exit.
  -n, --no-maintenance   Update system and Flatpaks only. Skip optional maintenance.
  -r, --reboot           Update system and Flatpaks only, then reboot.
  -q, --quiet            Reduce UPPY's own output where possible.
  -y, --yes              Answer yes to UPPY prompts.
      --verbose          Show commands before running them.
      --dry-run          Print privileged commands without running them.
      --check            Audit the system and print a status report only.
      --clean            Run package cleanup/cache cleanup only.
      --debloat          Run only the distro-specific debloat routine.
      --gaming           Install gaming applications only.
      --workstation      Install workstation applications only.
      --mounts           Configure NFS/iSCSI items only.
      --repair           Run iSCSI/filesystem repair checks only.
      --self-update      Download the latest uppy.sh from UPPY_UPDATE_URL.
      --backup           Export installed package/config info only.

Examples:
  uppy                  Interactive mode.
  uppy -n               Update only, skip optional maintenance.
  uppy -r               Update only, then reboot.
  uppy --debloat        Run only the debloat routine for this distro.
  uppy --check          Run a read-only system check.
  uppy --dry-run        Show what would be done without changing packages/files.
  UPPY_UPDATE_URL=https://example.com/uppy.sh uppy --self-update
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--no-maintenance)
                AUTO_SKIP_OPTIONAL=true
                ;;
            -r|--reboot)
                AUTO_SKIP_OPTIONAL=true
                AUTO_REBOOT=true
                ;;
            -q|--quiet)
                QUIET_MODE=true
                ;;
            -y|--yes)
                ASSUME_YES=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --debloat|--gaming|--workstation|--mounts|--repair|--self-update|--backup|--check|--clean)
                if [[ -n "$RUN_ONLY" ]]; then
                    echo "Only one run-only option can be used at a time."
                    echo
                    show_help
                    exit 1
                fi
                RUN_ONLY="${1#--}"
                ;;
            *)
                echo "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

msg() {
    if ! $QUIET_MODE; then
        echo "$@"
    fi
}

color_enabled() {
    [[ -t 1 && "${NO_COLOR:-}" == "" ]]
}

cecho() {
    local code="$1"
    shift
    if color_enabled; then
        printf '\033[%sm%s\033[0m\n' "$code" "$*"
    else
        printf '%s\n' "$*"
    fi
}

info() { cecho "36" "[INFO] $*"; }
success() { cecho "32" "[OK] $*"; }
warn() { cecho "33" "[WARN] $*"; }
error() { cecho "31" "[ERROR] $*"; }

log_msg() {
    local level="$1"
    shift || true
    [[ -n "$LOG_FILE" ]] || return 0
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

setup_logging() {
    if [[ $EUID -eq 0 ]]; then
        LOG_FILE="/var/log/uppy.log"
    else
        LOG_FILE="$HOME/uppy.log"
    fi

    if [[ $EUID -eq 0 ]]; then
        touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""
    else
        touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""
    fi

    if [[ -n "$LOG_FILE" ]]; then
        log_msg "INFO" "UPPY v${UPPY_VERSION} started as ${USER:-unknown} with args: $*"
        if $VERBOSE; then
            info "Logging to $LOG_FILE"
        fi
    fi
}

on_error() {
    local exit_code=$?
    local line_no=${1:-unknown}
    error "UPPY failed at line $line_no with exit code $exit_code"
    log_msg "ERROR" "Failed at line $line_no with exit code $exit_code"
    exit "$exit_code"
}
trap 'on_error $LINENO' ERR

install_manpage() {
    local man_dir="/usr/local/share/man/man1"
    local tmp_man=""

    tmp_man="$(mktemp)"
    cat > "$tmp_man" <<'MANPAGE'
.TH UPPY 1 "July 2026" "UPPY 2.0.1" "User Commands"
.SH NAME
uppy \- Linux update, maintenance and setup utility
.SH SYNOPSIS
.B uppy
[OPTIONS]
.SH DESCRIPTION
UPPY is a single-file Linux update, maintenance and setup utility for Arch, CachyOS, Nobara, Fedora and Debian-based systems.
It can update the operating system, update Flatpaks, configure NFS mounts, check iSCSI backup storage, run distro-specific debloat routines, install workstation and gaming Flatpaks, create backups, and install its own manual page and shell completion.
.SH OPTIONS
.TP
.BR -h ", " --help
Show help and exit.
.TP
.BR -n ", " --no-maintenance
Update the system and Flatpaks only, then skip optional maintenance.
.TP
.BR -r ", " --reboot
Update the system and Flatpaks only, skip optional maintenance, then reboot.
.TP
.BR -q ", " --quiet
Reduce UPPY's own output.
.TP
.BR -y ", " --yes
Answer yes to UPPY prompts.
.TP
.B --verbose
Show commands before running them.
.TP
.B --dry-run
Print privileged commands without running them.
.TP
.B --debloat
Run only the distro-specific debloat routine.
.TP
.B --gaming
Install gaming applications only.
.TP
.B --workstation
Install workstation applications only.
.TP
.B --mounts
Configure NFS/iSCSI items only.
.TP
.B --repair
Run iSCSI/filesystem repair checks only.
.TP
.B --backup
Export installed package and configuration information only.
.TP
.B --check
Run a read-only system check.
.TP
.B --clean
Run package cleanup and cache cleanup only.
.TP
.B --self-update
Download the latest uppy.sh from UPPY_UPDATE_URL and install it.
.SH EXAMPLES
.TP
.B uppy
Interactive update and maintenance mode.
.TP
.B uppy -n
Update only.
.TP
.B uppy -r
Update only, then reboot.
.TP
.B uppy --debloat
Run distro-specific debloat only.
.TP
.B uppy --check
Show a read-only system report.
.SH FILES
.TP
.I /usr/local/bin/uppy
Installed command.
.TP
.I /usr/local/share/man/man1/uppy.1.gz
Manual page installed by UPPY.
.TP
.I /etc/bash_completion.d/uppy
Bash completion installed by UPPY.
.TP
.I /var/log/uppy.log
Log file when run as root.
.TP
.I ~/uppy.log
Log file when run as a normal user.
.SH AUTHOR
Peter Haworth
.SH SEE ALSO
.BR apt (8),
.BR dnf (8),
.BR pacman (8),
.BR flatpak (1),
.BR iscsiadm (8),
.BR mount (8),
.BR systemctl (1)
MANPAGE

    run_sudo mkdir -p "$man_dir"
    if $DRY_RUN; then
        info "Dry-run: would install man page to $man_dir/uppy.1.gz"
        rm -f "$tmp_man"
        return 0
    fi
    gzip -9 -c "$tmp_man" | run_sudo tee "$man_dir/uppy.1.gz" >/dev/null
    rm -f "$tmp_man"

    if command -v mandb >/dev/null 2>&1; then
        run_sudo mandb -q || true
    elif command -v makewhatis >/dev/null 2>&1; then
        run_sudo makewhatis "$man_dir" || true
    else
        warn "mandb/makewhatis not found; man page installed but database was not refreshed."
    fi
}

install_bash_completion() {
    local completion_dir="/etc/bash_completion.d"
    local completion_file="$completion_dir/uppy"
    local tmp_completion=""

    tmp_completion="$(mktemp)"
    cat > "$tmp_completion" <<'COMPLETION'
_uppy_completion() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    local opts="-h --help -n --no-maintenance -r --reboot -q --quiet -y --yes --verbose --dry-run --debloat --gaming --workstation --mounts --repair --self-update --backup --check --clean"
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return 0
}
complete -F _uppy_completion uppy
COMPLETION

    run_sudo mkdir -p "$completion_dir"
    run_sudo install -m 644 "$tmp_completion" "$completion_file"
    rm -f "$tmp_completion"
}

ask() {
    local prompt="$1"
    local timeout="${2:-0}"
    local reply

    if $ASSUME_YES; then
        echo "$prompt [y/N]: y"
        return 0
    fi

    if (( timeout > 0 )); then
        read -r -t "$timeout" -p "$prompt [y/N] (${timeout}s): " reply || true
        echo
    else
        read -r -p "$prompt [y/N]: " reply
    fi

    reply=${reply:-N}

    [[ "$reply" =~ ^[Yy]$ ]]
}

parse_args "$@"

echo "UPPY v${UPPY_VERSION}"


if [[ ! -f /etc/os-release ]]; then
    echo "Cannot detect OS: /etc/os-release not found."
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" =~ ^(arch|cachyos|endeavouros|manjaro)$ ]] || [[ "${ID_LIKE:-}" =~ arch ]]; then
    DISTRO="arch"
elif [[ "${ID:-}" == "nobara" ]]; then
    DISTRO="nobara"
elif [[ "${ID:-}" =~ ^(fedora|aurora|bazzite)$ ]] || [[ "${ID_LIKE:-}" =~ fedora ]]; then
    DISTRO="fedora"
elif [[ "${ID:-}" =~ ^(ubuntu|debian|linuxmint|pop)$ ]] || [[ "${ID_LIKE:-}" =~ debian ]]; then
    DISTRO="debian"
else
    echo "Unsupported OS: ${ID:-unknown}"
    exit 1
fi

SCRIPT_PATH="$(readlink -f "$0")"

install_self() {
    local target="/usr/local/bin/uppy"

    if [[ "$SCRIPT_PATH" != "$target" ]]; then
        echo "Installing/updating uppy command..."
        run_sudo cp -f "$SCRIPT_PATH" "$target"
        run_sudo chmod 755 "$target"
    else
        echo "Running installed uppy command."
    fi

    install_manpage
    install_bash_completion
}

update_system() {
    echo
    echo "Updating system packages..."

    case "$DISTRO" in
        arch)
            run_sudo pacman -Syu --noconfirm
            ;;
        nobara)
            run_sudo nobara-updater cli
            ;;
        fedora)
            run_sudo dnf upgrade -y
            ;;
        debian)
            export DEBIAN_FRONTEND=noninteractive
            run_sudo apt update -y
            run_sudo apt full-upgrade -y
            ;;
    esac
}

cachyos_cleanup_and_gaming() {
    if [[ "${ID:-}" != "cachyos" ]]; then
        return 0
    fi

    echo
    echo "Running CachyOS cleanup and gaming setup..."

    local cachy_remove_packages=(
        alacritty
        meld
        jfsutils
        nilfs-utils
        usb_modeswitch
        xl2tpd
        kdegraphics-thumbnailers
        kdeplasma-addons
        plasma-browser-integration
        fwupd
    )

    local installed_cachy_remove=()
    local pkg

    for pkg in "${cachy_remove_packages[@]}"; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            installed_cachy_remove+=("$pkg")
        fi
    done

    if [[ ${#installed_cachy_remove[@]} -gt 0 ]]; then
        echo "Removing selected CachyOS packages:"
        printf '  %s\n' "${installed_cachy_remove[@]}"
        run_sudo pacman -Rns --noconfirm "${installed_cachy_remove[@]}"
    else
        echo "No selected CachyOS packages found to remove."
    fi

    echo
    echo "Installing CachyOS gaming packages..."
    run_sudo pacman -S --needed --noconfirm cachyos-gaming-meta open-iscsi
}

install_dependencies() {
    echo
    echo "Installing NFS/CIFS utilities and Flatpak..."

    case "$DISTRO" in
        arch)
            run_sudo pacman -S --needed --noconfirm nfs-utils cifs-utils flatpak
            ;;
        nobara|fedora)
            run_sudo dnf install -y nfs-utils cifs-utils flatpak
            ;;
        debian)
            export DEBIAN_FRONTEND=noninteractive
            run_sudo apt install -y nfs-common cifs-utils flatpak
            ;;
    esac
}

create_mountpoint() {
    local path="$1"

    if mountpoint -q "$path"; then
        echo "Already mounted: $path"
        return 0
    fi

    run_sudo mkdir -p "$path"
    run_sudo chmod 777 "$path"
    echo "Verified folder and permissions: $path"
}

add_comment() {
    local comment="$1"

    if ! grep -Fxq "$comment" /etc/fstab; then
        echo "$comment" | run_sudo tee -a /etc/fstab >/dev/null
    fi
}

add_nfs_mount() {
    local source="$1"
    local target="$2"
    local line="$source  $target  nfs  defaults,_netdev,noauto,x-systemd.automount  0  0"

    create_mountpoint "$target"

    if grep -Eq "^[^#]*[[:space:]]+$target[[:space:]]+" /etc/fstab; then
        echo "Mount point already exists in fstab, skipping: $target"
        return 0
    fi

    if grep -Fq "$source" /etc/fstab; then
        echo "Source already exists in fstab, skipping: $source"
        return 0
    fi

    echo "$line" | run_sudo tee -a /etc/fstab >/dev/null
    echo "Added: $line"
}

configure_nfs_mounts() {
    echo
    echo "Backing up /etc/fstab..."
    run_sudo cp /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

    echo
    echo "Adding NFS mounts..."

    add_comment "# Media/NAS Mounts"

    add_comment "# 192.168.0.212"
    add_nfs_mount "192.168.0.212:/mnt/HDDs/poolz"  "/mnt/poolz"

    add_comment "# 192.168.1.9"
    add_nfs_mount "192.168.1.9:/mnt/HDDs/bigbudda" "/mnt/bignfs"
    add_nfs_mount "192.168.1.9:/mnt/HDDs/Games"    "/mnt/games"
    add_nfs_mount "192.168.1.9:/mnt/HDDs/Movies"   "/mnt/movies-1"
    add_nfs_mount "192.168.1.9:/mnt/HDDs/Shows"    "/mnt/shows-1"
    add_nfs_mount "192.168.1.9:/mnt/HDDs/poolz"    "/mnt/poolz-1"
    add_nfs_mount "192.168.1.9:/mnt/HDDs/unifi"    "/mnt/unifi"
    add_nfs_mount "192.168.1.9:/mnt/HDDs/DLOAD"    "/mnt/dload-1"
    add_nfs_mount "192.168.1.9:/mnt/HDDs-2/6tb"    "/mnt/6tb"
}

find_buddybackup_device() {
    local dev=""

    dev="$(lsblk -rn -o NAME,LABEL,FSTYPE 2>/dev/null | awk '$2 == "buddybackup" && $3 == "ext4" {print "/dev/"$1; exit}')"

    if [[ -n "$dev" && -b "$dev" ]]; then
        echo "$dev"
        return 0
    fi

    if [[ -b /dev/sdk ]]; then
        echo "/dev/sdk"
        return 0
    fi

    return 1
}

check_iscsi_backup() {
    local mountpoint="/mnt/iscsi-backup"
    local device=""
    local mp=""

    echo
    echo "Checking iSCSI backup..."

    if ! device="$(find_buddybackup_device)"; then
        echo "iSCSI buddybackup device not found, skipping."
        return 0
    fi

    echo "Detected iSCSI backup device: $device"

    run_sudo mkdir -p "$mountpoint"

    if ! mountpoint -q "$mountpoint"; then
        echo "iSCSI backup not mounted at $mountpoint, mounting..."
        run_sudo mount "$device" "$mountpoint" || true
    fi

    if mountpoint -q "$mountpoint"; then
        if run_sudo touch "$mountpoint/.uppy-write-test" 2>/dev/null; then
            run_sudo rm -f "$mountpoint/.uppy-write-test"
            echo "iSCSI backup is writable."
            return 0
        fi

        echo
        echo "WARNING: iSCSI backup is mounted but not writable."
        echo "Attempting automatic repair..."

        while read -r mp; do
            [[ -n "$mp" ]] || continue
            echo "Unmounting $mp"
            run_sudo umount -l "$mp" || true
        done < <(findmnt "$device" -o TARGET -n 2>/dev/null || true)

        run_sudo e2fsck -fy "$device"

        run_sudo mkdir -p "$mountpoint"
        run_sudo mount "$device" "$mountpoint"

        if run_sudo touch "$mountpoint/.uppy-write-test" 2>/dev/null; then
            run_sudo rm -f "$mountpoint/.uppy-write-test"
            echo "iSCSI backup repaired and writable."
        else
            echo "WARNING: iSCSI backup is still not writable."
        fi
    else
        echo "iSCSI backup could not be mounted, skipping write check."
    fi
}

nobara_debloat() {
    if [[ "$DISTRO" != "nobara" ]]; then
        echo "Nobara debloat is Nobara-only, skipping."
        return 0
    fi

    echo
    echo "Running Nobara-only debloat..."
    echo "Keeping printing/scanning, YubiKey/smart-card support, WireGuard, Tailscale, KDE kfind/khelpcenter, and nobara-welcome."

    local remove_packages=(
        # VPN plugins not used by your current NetworkManager setup
        NetworkManager-l2tp
        NetworkManager-libreswan
        NetworkManager-libreswan-gnome
        NetworkManager-openconnect
        NetworkManager-openvpn
        NetworkManager-pptp
        NetworkManager-strongswan
        NetworkManager-strongswan-gnome
        NetworkManager-vpnc

        # Server packages not needed on the laptop
        mariadb-server
        mariadb-backup
        mariadb-embedded
        httpd-core
        mod_fcgid
        mod_perl

        # Accessibility packages not needed
        braille-printer-app
        orca
        espeak-ng
        brlapi

        # Legacy filesystem support not needed
        jfsutils
        nilfs-utils
        hfsplus-tools
        hfsutils
        gfs2-utils
        ocfs2-tools

        # Development packages not needed
        gcc-gfortran
        gettext-devel
        glibc-devel
        libomp-devel
        openssl-devel

        # Misc utilities not needed
        a2ps
        antiword
        enscript
        html2ps
        paps
        flatpost
        fpaste

        # KDE extras to remove; keeping kfind and khelpcenter
        kdebugsettings
        kcharselect
        kde-inotify-survey
        kwalletmanager5
    )

    local installed_remove=()
    local pkg=""

    for pkg in "${remove_packages[@]}"; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
            installed_remove+=("$pkg")
        fi
    done

    if [[ ${#installed_remove[@]} -eq 0 ]]; then
        echo "No Nobara debloat packages found to remove."
        return 0
    fi

    echo "The following installed packages will be removed:"
    printf '  %s\n' "${installed_remove[@]}"
    echo

    if ask "Proceed with Nobara debloat package removal?"; then
        run_sudo dnf remove -y "${installed_remove[@]}"
    else
        echo "Nobara debloat skipped."
    fi
}

update_flatpaks() {
    echo
    echo "Updating existing Flatpaks..."

    if command -v flatpak >/dev/null 2>&1; then
        flatpak update -y || true
    else
        echo "Flatpak not installed yet, skipping update."
    fi
}

remove_unused_packages() {
    echo
    echo "Removing unused packages..."

    case "$DISTRO" in
        arch)
            local orphans=""
            orphans="$(pacman -Qdtq 2>/dev/null || true)"
            if [[ -n "$orphans" ]]; then
                # shellcheck disable=SC2086
                run_sudo pacman -Rns --noconfirm $orphans
            else
                echo "No orphan packages found."
            fi
            ;;
        nobara|fedora)
            run_sudo dnf autoremove -y
            ;;
        debian)
            run_sudo apt autoremove -y
            ;;
    esac
}

clean_package_cache() {
    echo
    echo "Cleaning package cache..."

    case "$DISTRO" in
        arch)
            echo "Cleaning pacman cache..."
            run_sudo pacman -Scc --noconfirm

            if command -v yay >/dev/null 2>&1; then
                echo "Cleaning yay cache..."
                yay -Scc --noconfirm || true
                yes | yay -Sc >/dev/null 2>&1 || true
            fi

            if command -v paru >/dev/null 2>&1; then
                echo "Cleaning paru cache..."
                paru -Scc --noconfirm || true
                yes | paru -Sc >/dev/null 2>&1 || true
            fi
            ;;
        nobara|fedora)
            run_sudo dnf clean all
            ;;
        debian)
            run_sudo apt autoclean -y
            run_sudo apt clean
            ;;
    esac
}

clean_flatpak_runtimes() {
    echo
    echo "Cleaning unused Flatpak runtimes..."

    if command -v flatpak >/dev/null 2>&1; then
        flatpak uninstall --unused -y || true
    else
        echo "Flatpak not installed, skipping."
    fi
}

setup_flathub() {
    echo
    echo "Setting up Flathub..."

    if command -v flatpak >/dev/null 2>&1; then
        flatpak remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo
    else
        echo "Flatpak not installed, skipping Flathub setup."
    fi
}


install_workstation_apps() {
    setup_flathub
    local flatpaks=(
        com.discordapp.Discord
        com.spotify.Client
        org.qbittorrent.qBittorrent
        org.libreoffice.LibreOffice
        com.bitwarden.desktop
        com.brave.Browser
        org.mozilla.firefox
        org.videolan.VLC
    )
    for app in "${flatpaks[@]}"; do flatpak install -y flathub "$app" || true; done
}

install_gaming_apps() {
    setup_flathub
    local flatpaks=(
        com.usebottles.bottles
        com.heroicgameslauncher.hgl
        net.davidotek.pupgui2
        org.prismlauncher.PrismLauncher
    )
    for app in "${flatpaks[@]}"; do flatpak install -y flathub "$app" || true; done
}

uppy_backup() {
    local backup_dir="$HOME/uppy-backups/$(date +%Y%m%d-%H%M%S)"

    echo
    echo "Creating UPPY backup: $backup_dir"
    mkdir -p "$backup_dir"

    if command -v rpm >/dev/null 2>&1; then
        rpm -qa --qf "%{NAME}\n" | sort > "$backup_dir/all-rpm-packages.txt"
        dnf repoquery --userinstalled --qf "%{name}" 2>/dev/null | sort > "$backup_dir/userinstalled-rpm-packages.txt" || true
    fi

    if command -v pacman >/dev/null 2>&1; then
        pacman -Qqe | sort > "$backup_dir/userinstalled-pacman-packages.txt" || true
        pacman -Qq | sort > "$backup_dir/all-pacman-packages.txt" || true
    fi

    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='${Package}\n' | sort > "$backup_dir/all-dpkg-packages.txt" || true
    fi

    if command -v flatpak >/dev/null 2>&1; then
        flatpak list --app --columns=application > "$backup_dir/flatpak-apps.txt" || true
    fi

    cp /etc/os-release "$backup_dir/os-release" 2>/dev/null || true
    cp /etc/fstab "$backup_dir/fstab" 2>/dev/null || true
    nmcli connection show > "$backup_dir/nmcli-connections.txt" 2>/dev/null || true
    lsblk -f > "$backup_dir/lsblk-f.txt" 2>/dev/null || true

    echo "Backup complete: $backup_dir"
}

uppy_check() {
    echo
    echo "UPPY system check"
    echo "================="
    echo "Version: $UPPY_VERSION"
    echo "Distro type: ${DISTRO:-unknown}"
    echo

    echo "OS:"
    if [[ -f /etc/os-release ]]; then
        grep -E '^(PRETTY_NAME|ID|VERSION_ID)=' /etc/os-release || true
    fi
    echo

    echo "Kernel:"
    uname -a || true
    echo

    echo "Disk usage:"
    df -h / /home 2>/dev/null || df -h || true
    echo

    echo "Memory:"
    free -h || true
    echo

    echo "Failed systemd services:"
    systemctl --failed --no-pager 2>/dev/null || true
    echo

    echo "iSCSI sessions:"
    if command -v iscsiadm >/dev/null 2>&1; then
        run_sudo iscsiadm -m session || true
    else
        echo "iscsiadm not installed."
    fi
    echo

    echo "Configured NetworkManager connections:"
    nmcli -t -f NAME,TYPE connection show 2>/dev/null || true
    echo

    echo "Flatpak apps:"
    if command -v flatpak >/dev/null 2>&1; then
        flatpak list --app --columns=application 2>/dev/null || true
    else
        echo "flatpak not installed."
    fi
    echo

    echo "Potential orphan/unneeded packages:"
    case "$DISTRO" in
        arch)
            pacman -Qdtq 2>/dev/null || true
            ;;
        nobara|fedora)
            dnf repoquery --unneeded 2>/dev/null || true
            ;;
        debian)
            apt autoremove --dry-run 2>/dev/null | sed -n '/The following packages will be REMOVED:/,/^$/p' || true
            ;;
    esac
}

uppy_clean() {
    remove_unused_packages
    clean_package_cache
    clean_flatpak_runtimes
}

self_update() {
    local target="/usr/local/bin/uppy"
    local tmp=""

    echo
    echo "Running UPPY self-update..."

    if [[ -z "$UPPY_UPDATE_URL" ]]; then
        echo "UPPY_UPDATE_URL is not set."
        echo "Example: UPPY_UPDATE_URL=https://example.com/uppy.sh uppy --self-update"
        return 1
    fi

    tmp="$(mktemp)"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$UPPY_UPDATE_URL" -o "$tmp"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp" "$UPPY_UPDATE_URL"
    else
        echo "curl or wget is required for self-update."
        rm -f "$tmp"
        return 1
    fi

    bash -n "$tmp"
    run_sudo cp -f "$tmp" "$target"
    run_sudo chmod 755 "$target"
    rm -f "$tmp"

    echo "UPPY updated at $target"
}

run_only_mode() {
    case "$RUN_ONLY" in
        "")
            return 1
            ;;
        debloat)
            nobara_debloat
            ;;
        gaming)
            install_gaming_apps
            ;;
        workstation)
            install_workstation_apps
            ;;
        mounts)
            install_dependencies
            configure_nfs_mounts
            check_iscsi_backup
            ;;
        repair)
            check_iscsi_backup
            ;;
        self-update)
            self_update
            ;;
        backup)
            uppy_backup
            ;;
        check)
            uppy_check
            ;;
        clean)
            uppy_clean
            ;;
        *)
            echo "Unknown run-only mode: $RUN_ONLY"
            exit 1
            ;;
    esac

    reload_systemd
    echo
    echo "Finished."
    exit 0
}

reload_systemd() {
    echo
    echo "Reloading systemd..."

    if command -v systemctl >/dev/null 2>&1; then
        run_sudo systemctl daemon-reload
    else
        echo "systemctl not found, skipping daemon reload."
    fi
}

main() {
    setup_logging "$@"
    install_self

    if $DRY_RUN; then
        warn "Dry-run mode enabled: privileged commands will be printed instead of executed."
    fi
    echo "Detected distro type: $DISTRO"

    run_only_mode || true

    update_system
    update_flatpaks

    if ! $AUTO_SKIP_OPTIONAL && ask "Run optional maintenance tasks?" 5; then

        if ask "Run all optional tasks?"; then
            ask "Create UPPY backup first?" && uppy_backup
            ask "Install NFS/CIFS utilities?" && install_dependencies
            [[ "$ID" == "cachyos" ]] && cachyos_cleanup_and_gaming
            [[ "$DISTRO" == "nobara" ]] && nobara_debloat
            configure_nfs_mounts
            check_iscsi_backup
            remove_unused_packages
            clean_package_cache
            clean_flatpak_runtimes
            ask "Install workstation applications?" && install_workstation_apps
            ask "Install gaming applications?" && install_gaming_apps
        else
            ask "Create UPPY backup first?" && uppy_backup
            ask "Install NFS/CIFS utilities?" && install_dependencies
            [[ "$ID" == "cachyos" ]] && ask "Run CachyOS cleanup & gaming setup?" && cachyos_cleanup_and_gaming
            [[ "$DISTRO" == "nobara" ]] && ask "Run Nobara debloat?" && nobara_debloat
            ask "Configure NFS mounts?" && configure_nfs_mounts
            ask "Check & repair iSCSI backup?" && check_iscsi_backup
            ask "Remove orphan packages?" && remove_unused_packages
            ask "Clean package caches?" && clean_package_cache
            ask "Clean unused Flatpak runtimes?" && clean_flatpak_runtimes
            ask "Install workstation applications?" && install_workstation_apps
            ask "Install gaming applications?" && install_gaming_apps
        fi
    fi

    reload_systemd
    echo
    echo "Finished."

    if $AUTO_REBOOT; then
        echo
        echo "Rebooting in 5 seconds..."
        sleep 5
        run_sudo reboot
    fi
}

main "$@"
