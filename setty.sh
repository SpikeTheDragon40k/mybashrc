#!/bin/sh
# Distro- and installer-agnostic workstation setup script
# Supports: apt, dnf/yum, pacman, zypper, apk, xbps, emerge
# Author: Adriano "SpikeTheDragon" Inghingolo
#
# Usage: ./setty.sh [--gpu | --no-gpu] [--copy] [-y] [-h]

set -e

# --- Options ---
GPU_MODE="ask"    # ask | yes | no
BASHRC_MODE="auto" # auto (symlink when run from a git clone) | copy
ASSUME_YES=0

usage() {
    cat <<EOF
Usage: $0 [options]

  --gpu       Install the NVIDIA driver + hybrid graphics setup without asking
  --no-gpu    Skip the NVIDIA / hybrid graphics setup
  --copy      Copy .bashrc instead of symlinking it to this repo
  -y, --yes   Answer yes to every question
  -h, --help  Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --gpu) GPU_MODE="yes" ;;
        --no-gpu) GPU_MODE="no" ;;
        --copy) BASHRC_MODE="copy" ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

# --- Colors (only on a terminal that supports them) ---
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    RC=$(tput sgr0)
    RED=$(tput setaf 1)
    YELLOW=$(tput setaf 3)
    GREEN=$(tput setaf 2)
    BLUE=$(tput setaf 4)
else
    RC="" RED="" YELLOW="" GREEN="" BLUE=""
fi

print_colored() {
    printf "%s%s%s\n" "$1" "$2" "$RC"
}

# Things to tell the user at the end
NOTES=""
add_note() {
    NOTES="${NOTES}  - $1
"
}

# --- Command existence check ---
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Yes/no question (works when piped from curl too) ---
ask() {
    if [ "$ASSUME_YES" = "1" ]; then
        return 0
    fi
    if [ ! -r /dev/tty ]; then
        return 1
    fi
    printf "%s%s [y/N] %s" "$YELLOW" "$1" "$RC"
    read -r answer </dev/tty || answer=""
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# --- Root / sudo ---
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command_exists sudo; then
    SUDO="sudo"
else
    print_colored "$RED" "Error: run as root or install sudo first."
    exit 1
fi

# Directory of this script (empty when piped through curl | sh)
SCRIPT_DIR=""
if [ -f "$0" ]; then
    SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
fi

# --- Package manager detection ---
detect_pkg_manager() {
    PKG_MGR="unknown"
    DISTRO="unknown"
    NEEDS_EPEL=0
    NEEDS_CRB=0

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        # ID first, then ID_LIKE so derivatives (zorin, nobara, cachyos, ...) work too
        for id in ${ID:-} ${ID_LIKE:-}; do
            case "$id" in
                ubuntu|pop|linuxmint|elementary|zorin)
                    PKG_MGR="apt"; DISTRO="ubuntu" ;;
                debian|raspbian)
                    PKG_MGR="apt"; DISTRO="debian" ;;
                fedora)
                    PKG_MGR="dnf"; DISTRO="fedora" ;;
                rhel|centos|rocky|almalinux|ol)
                    PKG_MGR="dnf"; DISTRO="el"
                    # RHEL/EL family often needs EPEL + CRB for many tools
                    NEEDS_EPEL=1
                    NEEDS_CRB=1
                    ;;
                arch|manjaro|endeavouros|artix|cachyos)
                    PKG_MGR="pacman"; DISTRO="arch" ;;
                opensuse-tumbleweed|opensuse-leap|opensuse-slowroll|sles|opensuse|suse)
                    PKG_MGR="zypper"; DISTRO="opensuse" ;;
                alpine)
                    PKG_MGR="apk"; DISTRO="alpine" ;;
                void)
                    PKG_MGR="xbps"; DISTRO="void" ;;
                gentoo)
                    PKG_MGR="emerge"; DISTRO="gentoo" ;;
            esac
            if [ "$PKG_MGR" != "unknown" ]; then
                break
            fi
        done
    fi

    if [ "$PKG_MGR" = "unknown" ]; then
        if command_exists apt-get; then PKG_MGR="apt"
        elif command_exists dnf; then PKG_MGR="dnf"
        elif command_exists yum; then PKG_MGR="yum"
        elif command_exists pacman; then PKG_MGR="pacman"
        elif command_exists zypper; then PKG_MGR="zypper"
        elif command_exists apk; then PKG_MGR="apk"
        elif command_exists xbps-install; then PKG_MGR="xbps"
        elif command_exists emerge; then PKG_MGR="emerge"
        else
            print_colored "$RED" "Error: No supported package manager detected."
            exit 1
        fi
    fi

    # Immutable distros (Silverblue, Bazzite, Kinoite, ...) can't use dnf directly
    if [ -e /run/ostree-booted ]; then
        print_colored "$RED" "Error: rpm-ostree based (immutable) system detected. Use rpm-ostree / toolbox instead."
        exit 1
    fi

    print_colored "$GREEN" "Detected package manager: $PKG_MGR (distro family: $DISTRO)"
}

# --- Refresh package lists once (not on every install) ---
pkg_refresh() {
    print_colored "$BLUE" "Refreshing package lists..."
    case "$PKG_MGR" in
        apt) $SUDO apt-get update -qq ;;
        dnf) $SUDO dnf makecache -q || true ;;
        yum) $SUDO yum makecache -q || true ;;
        pacman) $SUDO pacman -Syu --noconfirm ;; # never -Sy alone: partial upgrades break Arch
        zypper) $SUDO zypper --non-interactive refresh ;;
        apk) $SUDO apk update ;;
        xbps) $SUDO xbps-install -Syu -y xbps ;;
        emerge) $SUDO emerge --sync ;;
    esac
}

# --- Is a package available in the configured repos? ---
pkg_available() {
    case "$PKG_MGR" in
        apt) apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]' ;;
        dnf) dnf -q info "$1" >/dev/null 2>&1 ;;
        yum) yum -q info "$1" >/dev/null 2>&1 ;;
        pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
        zypper) zypper --non-interactive -q search -x "$1" >/dev/null 2>&1 ;;
        apk) apk search -qe "$1" 2>/dev/null | grep -q . ;;
        xbps) xbps-query -R "$1" >/dev/null 2>&1 ;;
        emerge) return 0 ;;
        *) return 1 ;;
    esac
}

# --- Abstracted package installation ---
# Installs only the packages that exist in the repos, so one missing name
# doesn't make apt/dnf refuse the whole list. Returns 1 if anything was missing.
pkg_install() {
    to_install=""
    missing=""
    for pkg in "$@"; do
        if pkg_available "$pkg"; then
            to_install="$to_install $pkg"
        else
            missing="$missing $pkg"
        fi
    done

    if [ -n "$missing" ]; then
        print_colored "$YELLOW" "Not available in your repos:$missing"
    fi
    if [ -z "$to_install" ]; then
        [ -z "$missing" ]
        return
    fi

    # shellcheck disable=SC2086 # word splitting of the package list is intended
    case "$PKG_MGR" in
        apt)
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y $to_install
            ;;
        dnf)
            $SUDO dnf install -y $to_install
            ;;
        yum)
            $SUDO yum install -y $to_install
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm $to_install
            ;;
        zypper)
            $SUDO zypper --non-interactive install $to_install
            ;;
        apk)
            $SUDO apk add $to_install
            ;;
        xbps)
            $SUDO xbps-install -y $to_install
            ;;
        emerge)
            $SUDO emerge --noreplace $to_install
            ;;
        *)
            print_colored "$RED" "Error: Unsupported package manager '$PKG_MGR'."
            exit 1
            ;;
    esac

    [ -z "$missing" ]
}

# --- Enable EPEL/CRB on RHEL family ---
enable_extra_repos() {
    if [ "$DISTRO" != "el" ]; then
        return 0
    fi

    print_colored "$BLUE" "Enabling extra repositories for RHEL family..."

    # EPEL
    if [ "$NEEDS_EPEL" = "1" ]; then
        if ! dnf repolist 2>/dev/null | grep -qi epel; then
            print_colored "$YELLOW" "EPEL not detected. Installing epel-release..."
            # Try the generic epel-release first (CentOS Stream / Alma / Rocky)
            if $SUDO dnf install -y epel-release >/dev/null 2>&1; then
                print_colored "$GREEN" "EPEL repository enabled via epel-release."
            else
                # Fallback to direct RPM for RHEL
                $SUDO dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm" || true
                if dnf repolist 2>/dev/null | grep -qi epel; then
                    print_colored "$GREEN" "EPEL repository enabled via RPM."
                else
                    print_colored "$YELLOW" "Warning: Could not enable EPEL. Some packages may be unavailable."
                fi
            fi
        else
            print_colored "$GREEN" "EPEL repository already enabled."
        fi
    fi

    # CRB (CodeReady Builder) – needed by many EPEL packages
    if [ "$NEEDS_CRB" = "1" ]; then
        if command_exists crb; then
            # Helper shipped by epel-release
            $SUDO crb enable || true
        elif command_exists subscription-manager; then
            # RHEL with subscription
            $SUDO subscription-manager repos --enable "codeready-builder-for-rhel-$(rpm -E %rhel)-$(uname -m)-rpms" || true
        else
            $SUDO dnf config-manager --set-enabled crb || true
        fi
    fi
}

# --- Install Rust tools via cargo (fallback for EL and other limited repos) ---
cargo_install_if_missing() {
    bin_name="$1"
    crate_name="${2:-$1}"

    if command_exists "$bin_name"; then
        return 0
    fi

    if ! command_exists cargo; then
        print_colored "$YELLOW" "cargo not found. Installing Rust toolchain..."
        pkg_install cargo || pkg_install rust || true
    fi
    if ! command_exists cargo; then
        print_colored "$YELLOW" "No cargo available; skipping $crate_name."
        return 0
    fi

    print_colored "$YELLOW" "Installing $crate_name via cargo (this compiles, it can take a while)..."
    cargo install --locked "$crate_name" || print_colored "$YELLOW" "cargo install $crate_name failed; skipping."
}

# --- Core dependencies ---
install_dependencies() {
    print_colored "$BLUE" "Installing core dependencies..."

    # First, enable extra repos on RHEL family (EPEL/CRB)
    enable_extra_repos

    # Distro-specific package names
    case "$PKG_MGR" in
        apt) xz_pkg="xz-utils" notify_pkg="libnotify-bin" ;;
        *) xz_pkg="xz" notify_pkg="libnotify" ;;
    esac

    # Basics (also needed by the rest of this script)
    pkg_install curl git nano micro bash tar "$xz_pkg" tree wget unzip fontconfig bash-completion pciutils || true

    # Nice-to-have CLI tools; whatever is missing gets a fallback below
    pkg_install btop duf ripgrep bat multitail trash-cli zoxide fzf "$notify_pkg" || true

    # Fallbacks for EL / older releases
    if ! command_exists rg; then
        cargo_install_if_missing rg ripgrep
    fi
    if ! command_exists bat && ! command_exists batcat; then
        cargo_install_if_missing bat bat
    fi
    if ! command_exists zoxide; then
        print_colored "$YELLOW" "zoxide not packaged. Installing with the official installer to ~/.local/bin..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh || \
            print_colored "$YELLOW" "zoxide install failed; skipping."
    fi
    command_exists btop || add_note "btop not available on this distro."
    command_exists duf || add_note "duf not available on this distro (it's a Go tool: 'go install github.com/muesli/duf@latest')."
}

# --- fastfetch installation ---
install_fastfetch() {
    print_colored "$BLUE" "Installing fastfetch..."

    if command_exists fastfetch; then
        print_colored "$GREEN" "fastfetch already installed."
        return 0
    fi

    if pkg_install fastfetch; then
        return 0
    fi

    case "$PKG_MGR" in
        apt)
            # Ubuntu 24.04 and Debian 12 don't package it
            if [ "$DISTRO" = "ubuntu" ] && command_exists add-apt-repository; then
                $SUDO add-apt-repository -y ppa:zhangsongcui3371/fastfetch && pkg_refresh && pkg_install fastfetch && return 0
            fi
            # Official .deb from GitHub
            case "$(dpkg --print-architecture)" in
                amd64) ff_arch="amd64" ;;
                arm64) ff_arch="aarch64" ;;
                *) ff_arch="" ;;
            esac
            if [ -n "$ff_arch" ]; then
                ff_tmp=$(mktemp -d)
                if curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$ff_arch.deb" -o "$ff_tmp/fastfetch.deb"; then
                    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$ff_tmp/fastfetch.deb" || true
                fi
                rm -rf "$ff_tmp"
            fi
            ;;
    esac

    command_exists fastfetch || add_note "fastfetch could not be installed."
}

# --- ble.sh (syntax highlighting / autosuggestions for bash) ---
install_blesh() {
    print_colored "$BLUE" "Installing ble.sh..."

    if [ -f /usr/share/blesh/ble.sh ] || [ -f "$HOME/.local/share/blesh/ble.sh" ]; then
        print_colored "$GREEN" "ble.sh already installed."
        return 0
    fi

    # Packaged on Fedora, openSUSE, Void...
    if pkg_install blesh 2>/dev/null; then
        return 0
    fi

    # Otherwise install the official nightly build for this user
    print_colored "$YELLOW" "Installing ble.sh nightly to ~/.local/share/blesh..."
    blesh_tmp=$(mktemp -d)
    if curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar -xJf - -C "$blesh_tmp"; then
        bash "$blesh_tmp"/ble-nightly/ble.sh --install "$HOME/.local/share" || add_note "ble.sh install failed."
    else
        add_note "Could not download ble.sh."
    fi
    rm -rf "$blesh_tmp"
}

# --- Nerd Font installation ---
install_font() {
    FONT_NAME="MesloLGS Nerd Font Mono"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_DIR="$HOME/.local/share/fonts/Meslo"

    print_colored "$BLUE" "Checking font: $FONT_NAME..."

    if fc-list : family 2>/dev/null | grep -iq "$FONT_NAME"; then
        print_colored "$GREEN" "Font '$FONT_NAME' is already installed."
        return 0
    fi

    print_colored "$YELLOW" "Installing font '$FONT_NAME'..."

    font_tmp=$(mktemp -d)
    if curl -fsSL "$FONT_URL" -o "$font_tmp/Meslo.zip" && unzip -q "$font_tmp/Meslo.zip" -d "$font_tmp"; then
        mkdir -p "$FONT_DIR"
        find "$font_tmp" -type f -name "*.ttf" -exec mv {} "$FONT_DIR"/ \;
        fc-cache -f >/dev/null 2>&1 || true
        print_colored "$GREEN" "Font '$FONT_NAME' installed successfully."
    else
        print_colored "$RED" "Font download failed. Skipping font installation."
        add_note "Nerd Font not installed."
    fi
    rm -rf "$font_tmp"
}

# --- Starship and fzf ---
install_starship_and_fzf() {
    print_colored "$BLUE" "Setting up Starship and fzf..."

    # Starship: package first, then the official installer into ~/.local/bin (no sudo needed)
    if ! command_exists starship && ! [ -x "$HOME/.local/bin/starship" ]; then
        if ! pkg_install starship 2>/dev/null; then
            print_colored "$YELLOW" "Installing Starship with the official installer..."
            mkdir -p "$HOME/.local/bin"
            if ! curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; then
                print_colored "$RED" "Something went wrong during Starship install!"
                add_note "Starship not installed."
            fi
        fi
    else
        print_colored "$GREEN" "Starship already installed."
    fi

    # fzf (fallback if package install failed)
    if ! command_exists fzf; then
        if [ -d "$HOME/.fzf" ]; then
            print_colored "$YELLOW" "fzf directory already exists. Skipping installation."
        else
            print_colored "$YELLOW" "Installing fzf via git..."
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
            "$HOME/.fzf/install" --bin >/dev/null 2>&1 || true
        fi
    else
        print_colored "$GREEN" "fzf already installed."
    fi
}

# --- Starship preset ---
set_starship_preset() {
    print_colored "$BLUE" "Configuring Starship preset..."

    starship_bin=$(command -v starship 2>/dev/null || true)
    [ -z "$starship_bin" ] && [ -x "$HOME/.local/bin/starship" ] && starship_bin="$HOME/.local/bin/starship"
    if [ -z "$starship_bin" ]; then
        print_colored "$YELLOW" "Starship not found. Skipping preset configuration."
        return 0
    fi

    # Don't overwrite a config you already tweaked
    if [ -f "$HOME/.config/starship.toml" ]; then
        print_colored "$GREEN" "~/.config/starship.toml already exists, leaving it alone."
        return 0
    fi

    mkdir -p "$HOME/.config"
    "$starship_bin" preset bracketed-segments -o "$HOME/.config/starship.toml"
    print_colored "$GREEN" "Starship preset applied."
}

# --- .bashrc management ---
copy_bashrc() {
    print_colored "$BLUE" "Updating .bashrc..."

    BASHRC_URL="https://raw.githubusercontent.com/SpikeTheDragon40k/mybashrc/refs/heads/main/.bashrc"
    BACKUP_PATH="$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)"
    LOCAL_BASHRC=""
    [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/.bashrc" ] && LOCAL_BASHRC="$SCRIPT_DIR/.bashrc"

    # Already linked to this repo: nothing to do
    if [ -n "$LOCAL_BASHRC" ] && [ -L "$HOME/.bashrc" ] && [ "$(readlink -f "$HOME/.bashrc")" = "$(readlink -f "$LOCAL_BASHRC")" ]; then
        print_colored "$GREEN" "~/.bashrc already points to $LOCAL_BASHRC"
        return 0
    fi

    if [ -e "$HOME/.bashrc" ] || [ -L "$HOME/.bashrc" ]; then
        print_colored "$YELLOW" "Backing up current .bashrc to $BACKUP_PATH"
        cp -P "$HOME/.bashrc" "$BACKUP_PATH"
    fi

    if [ -n "$LOCAL_BASHRC" ] && [ "$BASHRC_MODE" = "auto" ] && [ -d "$SCRIPT_DIR/.git" ]; then
        # Symlink, so 'git pull' in the repo updates every machine
        ln -sf "$LOCAL_BASHRC" "$HOME/.bashrc"
        print_colored "$GREEN" "~/.bashrc is now a symlink to $LOCAL_BASHRC"
    elif [ -n "$LOCAL_BASHRC" ]; then
        rm -f "$HOME/.bashrc"
        cp "$LOCAL_BASHRC" "$HOME/.bashrc"
        print_colored "$GREEN" "Copied $LOCAL_BASHRC to ~/.bashrc"
    else
        print_colored "$YELLOW" "Downloading new .bashrc from $BASHRC_URL"
        if ! curl -fsSL "$BASHRC_URL" -o "$HOME/.bashrc.new"; then
            print_colored "$RED" "Failed to download .bashrc."
            exit 1
        fi
        rm -f "$HOME/.bashrc"
        mv "$HOME/.bashrc.new" "$HOME/.bashrc"
        print_colored "$GREEN" ".bashrc successfully updated."
    fi

    print_colored "$BLUE" "Put machine-specific settings in ~/.bashrc.local (it's sourced automatically)."
}

#######################################################
# LAPTOP / HYBRID GRAPHICS (AMD iGPU + NVIDIA dGPU)
#######################################################

# True for laptop chassis types (notebook, laptop, convertible, ...)
is_laptop() {
    case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in
        8|9|10|14|31|32) return 0 ;;
        *) return 1 ;;
    esac
}

# GPU vendor present? 0x10de = NVIDIA, 0x1002 = AMD
has_gpu_vendor() {
    for dev in /sys/bus/pci/devices/*; do
        [ "$(cat "$dev/vendor" 2>/dev/null)" = "$1" ] || continue
        case "$(cat "$dev/class" 2>/dev/null)" in
            0x03*) return 0 ;;
        esac
    done
    return 1
}

has_systemd() {
    [ -d /run/systemd/system ]
}

# Enables a systemd unit only if it exists
enable_unit() {
    if has_systemd && systemctl list-unit-files "$1" 2>/dev/null | grep -q "^$1"; then
        if $SUDO systemctl enable "$1" >/dev/null 2>&1; then
            print_colored "$GREEN" "Enabled $1"
        fi
    fi
    return 0
}

# Highest version of a "name-<NUM>-suffix" style package, e.g. nvidia-driver-580-open
apt_latest_versioned() {
    apt-cache pkgnames "$1" 2>/dev/null | grep -E "^$1[0-9]+$2\$" | sort -V | tail -n 1
}

install_nvidia_driver() {
    print_colored "$BLUE" "Installing the NVIDIA driver (open kernel modules, required for RTX 50 series)..."

    if [ -f /proc/driver/nvidia/version ]; then
        print_colored "$GREEN" "NVIDIA driver already loaded: $(head -n 1 /proc/driver/nvidia/version)"
        return 0
    fi

    case "$DISTRO" in
        ubuntu)
            if [ "${ID:-}" = "pop" ]; then
                add_note "Pop!_OS: use the NVIDIA ISO or 'sudo apt install system76-driver-nvidia'."
                return 0
            fi
            nv_pkg=$(apt_latest_versioned nvidia-driver- -open)
            nv_ver=$(echo "$nv_pkg" | tr -dc '0-9')
            if [ -n "$nv_pkg" ] && [ "$nv_ver" -ge 570 ]; then
                pkg_install "linux-headers-$(uname -r)" || true
                pkg_install "$nv_pkg"
            else
                add_note "No nvidia-driver-5xx-open (>= 570) in your repos. Try 'sudo ubuntu-drivers install' or the graphics-drivers PPA."
            fi
            ;;
        debian)
            # Debian's own packages may be too old for Blackwell; use NVIDIA's repo in that case
            nv_ver=$(apt-cache policy nvidia-open-kernel-dkms 2>/dev/null | sed -n 's/.*Candidate: \([0-9]*\).*/\1/p')
            pkg_install "linux-headers-$(uname -r)" || true
            if [ -n "$nv_ver" ] && [ "$nv_ver" -ge 570 ]; then
                pkg_install nvidia-open-kernel-dkms nvidia-driver firmware-misc-nonfree
            else
                print_colored "$YELLOW" "Debian's driver is missing or older than 570, using NVIDIA's official repo..."
                nv_tmp=$(mktemp -d)
                nv_repo="debian${VERSION_ID:-13}"
                if curl -fsSL "https://developer.download.nvidia.com/compute/cuda/repos/$nv_repo/x86_64/cuda-keyring_1.1-1_all.deb" -o "$nv_tmp/cuda-keyring.deb"; then
                    $SUDO dpkg -i "$nv_tmp/cuda-keyring.deb"
                    pkg_refresh
                    pkg_install nvidia-open
                else
                    add_note "Could not reach NVIDIA's $nv_repo repo. See https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/"
                fi
                rm -rf "$nv_tmp"
            fi
            ;;
        fedora|el)
            if [ "$DISTRO" = "fedora" ]; then
                rf_path="fedora" rf_ver=$(rpm -E %fedora)
            else
                rf_path="el" rf_ver=$(rpm -E %rhel)
            fi
            if ! dnf repolist 2>/dev/null | grep -qi rpmfusion-nonfree; then
                print_colored "$YELLOW" "Enabling RPM Fusion..."
                $SUDO dnf install -y \
                    "https://mirrors.rpmfusion.org/free/$rf_path/rpmfusion-free-release-$rf_ver.noarch.rpm" \
                    "https://mirrors.rpmfusion.org/nonfree/$rf_path/rpmfusion-nonfree-release-$rf_ver.noarch.rpm"
            fi
            # Build the open kernel modules (the closed ones don't support RTX 50)
            echo "%_with_kmod_nvidia_open 1" | $SUDO tee /etc/rpm/macros.nvidia-kmod >/dev/null
            pkg_install akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-power
            add_note "Fedora: wait ~5 min before rebooting so akmods can build the module (check: 'modinfo -F version nvidia')."
            if command_exists mokutil && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
                add_note "Secure Boot is on: run 'sudo mokutil --import /etc/pki/akmods/certs/public_key.der' and enroll the key on next boot."
            fi
            ;;
        arch)
            if [ "${ID:-}" = "cachyos" ] && command_exists chwd; then
                add_note "CachyOS: use 'sudo chwd -a' to install the NVIDIA driver."
                return 0
            fi
            # Stock 'linux' kernel only -> prebuilt module; any other kernel -> dkms + headers
            nv_pkgs="nvidia-utils nvidia-settings nvidia-prime"
            kernels=$(pacman -Qq 2>/dev/null | grep -E '^linux(-lts|-zen|-hardened|-rt|-cachyos)?$' || true)
            if [ "$kernels" = "linux" ]; then
                nv_pkgs="nvidia-open $nv_pkgs"
            else
                nv_pkgs="nvidia-open-dkms $nv_pkgs"
                for k in $kernels; do
                    nv_pkgs="$nv_pkgs $k-headers"
                done
            fi
            # shellcheck disable=SC2086
            pkg_install $nv_pkgs
            pkg_install lib32-nvidia-utils 2>/dev/null || add_note "Enable [multilib] in /etc/pacman.conf for 32-bit (Steam) support, then install lib32-nvidia-utils."
            ;;
        opensuse)
            add_note "openSUSE: run 'sudo zypper install openSUSE-repos-\$(. /etc/os-release; echo \$NAME | tr ' ' '-')-NVIDIA' then 'sudo zypper install-new-recommends'."
            return 0
            ;;
        *)
            add_note "Automatic NVIDIA install not supported on $DISTRO; install the open kernel modules (>= 570) manually."
            return 0
            ;;
    esac
}

configure_nvidia_power() {
    print_colored "$BLUE" "Configuring NVIDIA power management (dGPU sleeps when idle, suspend works)..."

    # Keep VRAM across suspend and let the dGPU power off when unused
    if ! grep -rqs "PreserveVideoMemoryAllocations\|DynamicPowerManagement" /etc/modprobe.d /usr/lib/modprobe.d /lib/modprobe.d; then
        printf '%s\n' \
            "# Added by setty.sh" \
            "options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp" \
            "options nvidia NVreg_DynamicPowerManagement=0x02" \
            | $SUDO tee /etc/modprobe.d/nvidia-power.conf >/dev/null
        print_colored "$GREEN" "Wrote /etc/modprobe.d/nvidia-power.conf"
    fi

    enable_unit nvidia-suspend.service
    enable_unit nvidia-resume.service
    enable_unit nvidia-hibernate.service
    enable_unit nvidia-suspend-then-hibernate.service
    # Dynamic Boost: shifts power between CPU and dGPU on laptops
    enable_unit nvidia-powerd.service
}

setup_laptop() {
    print_colored "$BLUE" "Installing laptop tools..."

    # Firmware/BIOS updates and GPU monitoring (nvtop shows AMD and NVIDIA)
    pkg_install fwupd nvtop || true

    # AMD iGPU: Vulkan + hardware video decode (keeps video playback on the iGPU, saves battery)
    case "$PKG_MGR" in
        apt) pkg_install mesa-vulkan-drivers mesa-va-drivers vainfo || true ;;
        dnf) pkg_install mesa-vulkan-drivers mesa-va-drivers libva-utils || true ;;
        pacman) pkg_install vulkan-radeon libva-utils || true ;;
        zypper) pkg_install libvulkan_radeon Mesa-dri libva-utils || true ;;
    esac
    # Fedora's mesa ships without H.264/HEVC; RPM Fusion's freeworld build has them
    if [ "$DISTRO" = "fedora" ] && dnf repolist 2>/dev/null | grep -qi rpmfusion-free; then
        $SUDO dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld >/dev/null 2>&1 || true
    fi

    # Power profiles: only if nothing else manages power (TLP conflicts with ppd)
    if has_systemd && ! systemctl list-unit-files 2>/dev/null | grep -qE '^(power-profiles-daemon|tuned-ppd|tlp)\.service'; then
        pkg_install power-profiles-daemon || true
        enable_unit power-profiles-daemon.service
    fi

    case "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)" in
        *ASUS*) add_note "ASUS laptop: asusctl + supergfxctl (https://asus-linux.org) give you fan curves, battery limit and GPU modes." ;;
    esac
}

setup_hybrid_gpu() {
    has_gpu_vendor 0x10de || return 0

    if [ "$(systemd-detect-virt 2>/dev/null || echo none)" != "none" ]; then
        return 0
    fi

    case "$GPU_MODE" in
        no) return 0 ;;
        ask)
            ask "NVIDIA GPU detected. Install the driver and configure hybrid graphics?" || return 0
            ;;
    esac

    install_nvidia_driver || add_note "NVIDIA driver install hit an error, check the output above."
    configure_nvidia_power

    if has_gpu_vendor 0x1002 || has_gpu_vendor 0x8086; then
        # "Launch using discrete GPU" in GNOME/KDE menus
        pkg_install switcheroo-control || true
        enable_unit switcheroo-control.service
        add_note "Run apps on the dGPU with 'prime-run <app>'. Check if it's asleep with 'dgpu' (should say 'suspended')."
    fi

    add_note "Reboot to load the NVIDIA driver, then verify with 'nvidia-smi'."
}

# --- Main ---
main() {
    print_colored "$BLUE" "Starting workstation setup..."

    detect_pkg_manager
    pkg_refresh
    install_dependencies
    install_fastfetch
    install_blesh
    install_font
    install_starship_and_fzf
    set_starship_preset
    copy_bashrc

    if is_laptop; then
        setup_laptop
    fi
    setup_hybrid_gpu

    print_colored "$GREEN" "Workstation setup completed successfully!"
    if [ -n "$NOTES" ]; then
        print_colored "$YELLOW" "Notes:"
        printf "%s" "$NOTES"
    fi
    print_colored "$BLUE" "Run 'exec bash' or restart your terminal to apply changes."
}

main
