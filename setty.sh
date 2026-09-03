#!/bin/sh -e
# Distro- and installer-agnostic workstation setup script
# Supports: apt/nala, dnf/yum, pacman, zypper, apk, xbps, emerge
# Author: Adriano "SpikeTheDragon" Inghingolo

set -e

# --- Colors ---
RC=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)

print_colored() {
    printf "${1}%s${RC}\n" "$2"
}

# --- Package manager detection ---
detect_pkg_manager() {
    PKG_MGR="unknown"
    NEEDS_EPEL=0
    NEEDS_CRB=0

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|linuxmint|pop)
                PKG_MGR="apt"
                ;;
            fedora)
                PKG_MGR="dnf"
                ;;
            rhel|centos|rocky|almalinux|ol)
                PKG_MGR="dnf"
                # RHEL/EL10 family often needs EPEL + CRB for many tools
                NEEDS_EPEL=1
                NEEDS_CRB=1
                ;;
            arch|manjaro|endeavouros|artix)
                PKG_MGR="pacman"
                ;;
            opensuse-tumbleweed|opensuse-leap|sles|opensuse)
                PKG_MGR="zypper"
                ;;
            alpine)
                PKG_MGR="apk"
                ;;
            void)
                PKG_MGR="xbps"
                ;;
            gentoo)
                PKG_MGR="emerge"
                ;;
        esac
    fi

    if [ "$PKG_MGR" = "unknown" ]; then
        if command -v apt >/dev/null 2>&1; then PKG_MGR="apt"
        elif command -v dnf >/dev/null 2>&1; then PKG_MGR="dnf"
        elif command -v yum >/dev/null 2>&1; then PKG_MGR="yum"
        elif command -v pacman >/dev/null 2>&1; then PKG_MGR="pacman"
        elif command -v zypper >/dev/null 2>&1; then PKG_MGR="zypper"
        elif command -v apk >/dev/null 2>&1; then PKG_MGR="apk"
        elif command -v xbps-install >/dev/null 2>&1; then PKG_MGR="xbps"
        elif command -v emerge >/dev/null 2>&1; then PKG_MGR="emerge"
        else
            print_colored "$RED" "Error: No supported package manager detected."
            exit 1
        fi
    fi

    if [ "$PKG_MGR" = "apt" ] && command -v nala >/dev/null 2>&1; then
        PKG_MGR="nala"
    fi

    print_colored "$GREEN" "Detected package manager: $PKG_MGR"

    # Export for helper functions
    export PKG_MGR NEEDS_EPEL NEEDS_CRB
}

# --- Enable EPEL/CRB on RHEL family ---
enable_extra_repos() {
    if [ "$PKG_MGR" != "dnf" ]; then
        return 0
    fi

    if [ "$NEEDS_EPEL" = "1" ] || [ "$NEEDS_CRB" = "1" ]; then
        print_colored "$BLUE" "Enabling extra repositories for RHEL family..."

        # CRB (CodeReady Builder) – needed for some packages on EL10
        if [ "$NEEDS_CRB" = "1" ]; then
            if command -v subscription-manager >/dev/null 2>&1; then
                # RHEL with subscription
                subscription-manager repos --enable codeready-builder-for-rhel-10-"$(uname -m)"-rpms 2>/dev/null || true
            else
                # CentOS/Rocky/Alma: enable crb via dnf config-manager
                dnf config-manager --set-enabled crb 2>/dev/null || true
            fi
        fi

        # EPEL
        if [ "$NEEDS_EPEL" = "1" ]; then
            if ! dnf repolist | grep -qi epel; then
                print_colored "$YELLOW" "EPEL not detected. Installing epel-release..."
                # Try the generic epel-release first (CentOS Stream style)
                if dnf install -y epel-release >/dev/null 2>&1; then
                    print_colored "$GREEN" "EPEL repository enabled via epel-release."
                else
                    # Fallback to direct RPM for RHEL/Alma/Rocky
                    dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm" || true
                    if dnf repolist | grep -qi epel; then
                        print_colored "$GREEN" "EPEL repository enabled via RPM."
                    else
                        print_colored "$YELLOW" "Warning: Could not enable EPEL. Some packages may be unavailable."
                    fi
                fi
            else
                print_colored "$GREEN" "EPEL repository already enabled."
            fi
        fi
    fi
}

# --- Abstracted package installation ---
pkg_install() {
    case "$PKG_MGR" in
        apt)
            sudo apt update -qq
            sudo apt install -y "$@"
            ;;
        nala)
            sudo nala update -qq
            sudo nala install -y "$@"
            ;;
        dnf)
            sudo dnf install -y "$@"
            ;;
        yum)
            sudo yum install -y "$@"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "$@"
            ;;
        zypper)
            sudo zypper refresh
            sudo zypper install -y "$@"
            ;;
        apk)
            sudo apk update
            sudo apk add "$@"
            ;;
        xbps)
            sudo xbps-install -Syu xbps -y
            sudo xbps-install -y "$@"
            ;;
        emerge)
            sudo emerge --sync
            sudo emerge "$@"
            ;;
        *)
            print_colored "$RED" "Error: Unsupported package manager '$PKG_MGR'."
            exit 1
            ;;
    esac
}

# --- Install Rust tools via cargo (fallback) ---
cargo_install_if_missing() {
    bin_name="$1"
    crate_name="${2:-$1}"

    if command -v "$bin_name" >/dev/null 2>&1; then
        print_colored "$GREEN" "$bin_name already installed."
        return 0
    fi

    if ! command -v cargo >/dev/null 2>&1; then
        print_colored "$YELLOW" "cargo not found. Installing Rust toolchain..."
        case "$PKG_MGR" in
            apt|nala)
                pkg_install rustc cargo
                ;;
            dnf|yum)
                pkg_install cargo rust
                ;;
            pacman)
                pkg_install rust
                ;;
            zypper)
                pkg_install rust cargo
                ;;
            apk)
                pkg_install rust cargo
                ;;
            *)
                print_colored "$RED" "Cannot install cargo on this distro automatically."
                return 1
                ;;
        esac
    fi

    print_colored "$YELLOW" "Installing $crate_name via cargo..."
    cargo install --locked "$crate_name"
}

# --- fastfetch installation ---
install_fastfetch() {
    print_colored "$BLUE" "Installing fastfetch..."

    case "$PKG_MGR" in
        apt|nala)
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                case "$ID" in
                    ubuntu)
                        if command -v add-apt-repository >/dev/null 2>&1; then
                            sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch 2>/dev/null || true
                        fi
                        ;;
                esac
            fi
            pkg_install fastfetch
            ;;
        *)
            pkg_install fastfetch
            ;;
    esac
}

# --- Core dependencies ---
install_dependencies() {
    print_colored "$BLUE" "Installing core dependencies..."

    # First, enable extra repos on RHEL family (EPEL/CRB)
    enable_extra_repos

    # Common packages available across most distros
    # Note: on some EL10 systems, a few of these may require EPEL/CRB or cargo fallback
    pkg_install curl git nano bash tar tree wget unzip fontconfig bash-completion || true

    # Try to install the rest; failures will be handled by fallbacks later
    pkg_install btop duf ripgrep bat multitail trash-cli zoxide fzf 2>/dev/null || true

    # Fallback installs for EL10 / limited repos
    if ! command -v btop >/dev/null 2>&1; then
        print_colored "$YELLOW" "btop not found via dnf. Installing from repo..."
        pkg_install btop || cargo_install_if_missing btop bottom
    fi

    if ! command -v duf >/dev/null 2>&1; then
        print_colored "$YELLOW" "duf not found via dnf. Installing via cargo..."
        cargo_install_if_missing duf duf
    fi

    if ! command -v rg >/dev/null 2>&1; then
        print_colored "$YELLOW" "ripgrep not found via dnf. Installing via cargo..."
        cargo_install_if_missing rg ripgrep
    fi

    if ! command -v bat >/dev/null 2>&1; then
        print_colored "$YELLOW" "bat not found via dnf. Installing via cargo..."
        cargo_install_if_missing bat bat
    fi

    if ! command -v multitail >/dev/null 2>&1; then
        print_colored "$YELLOW" "multitail not found via dnf. Installing..."
        pkg_install multitail || print_colored "$YELLOW" "multitail not available; skipping."
    fi

    if ! command -v trash >/dev/null 2>&1; then
        print_colored "$YELLOW" "trash-cli not found via dnf. Installing..."
        pkg_install trash-cli || print_colored "$YELLOW" "trash-cli not available; skipping."
    fi

    if ! command -v zoxide >/dev/null 2>&1; then
        print_colored "$YELLOW" "zoxide not found via dnf. Installing via cargo..."
        cargo_install_if_missing zoxide zoxide
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        print_colored "$YELLOW" "fzf not found via dnf. Installing..."
        pkg_install fzf || print_colored "$YELLOW" "fzf not available; will install via git later if needed."
    fi
}

# --- Nerd Font installation ---
install_font() {
    print_colored "$BLUE" "Checking font: MesloLGS Nerd Font Mono..."

    FONT_NAME="MesloLGS Nerd Font Mono"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_DIR="$HOME/.local/share/fonts"

    if fc-list :family | grep -iq "$FONT_NAME"; then
        print_colored "$GREEN" "Font '$FONT_NAME' is already installed."
        return 0
    fi

    print_colored "$YELLOW" "Installing font '$FONT_NAME'..."

    if ! wget -q --spider "$FONT_URL"; then
        print_colored "$RED" "Font URL is not accessible. Skipping font installation."
        return 1
    fi

    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT

    wget -q "$FONT_URL" -O "$TEMP_DIR"/Meslo.zip
    unzip -q "$TEMP_DIR"/Meslo.zip -d "$TEMP_DIR"

    mkdir -p "$FONT_DIR"/"$FONT_NAME"
    find "$TEMP_DIR" -type f -name "*.ttf" -exec mv {} "$FONT_DIR"/"$FONT_NAME"/ \;

    fc-cache -fv >/dev/null 2>&1
    print_colored "$GREEN" "Font '$FONT_NAME' installed successfully."
}

# --- Command existence check ---
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Starship and fzf ---
install_starship_and_fzf() {
    print_colored "$BLUE" "Setting up Starship and fzf..."

    # Starship
    if ! command_exists starship; then
        print_colored "$YELLOW" "Installing Starship..."
        if ! curl -sS https://starship.rs/install.sh | sh; then
            print_colored "$RED" "Something went wrong during Starship install!"
            exit 1
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
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            ~/.fzf/install --no-update-rcfiles >/dev/null 2>&1 || true
        fi
    else
        print_colored "$GREEN" "fzf already installed."
    fi
}

# --- Starship preset ---
set_starship_preset() {
    print_colored "$BLUE" "Configuring Starship preset..."

    if ! command_exists starship; then
        print_colored "$YELLOW" "Starship not found. Skipping preset configuration."
        return 0
    fi

    mkdir -p "$HOME/.config"
    starship preset bracketed-segments -o "$HOME/.config/starship.toml"
    print_colored "$GREEN" "Starship preset applied."
}

# --- .bashrc management ---
copy_bashrc() {
    print_colored "$BLUE" "Updating .bashrc..."

    BASHRC_URL="https://raw.githubusercontent.com/SpikeTheDragon40k/mybashrc/refs/heads/main/.bashrc"
    BACKUP_PATH="$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)"

    if [ -f "$HOME/.bashrc" ]; then
        print_colored "$YELLOW" "Backing up current .bashrc to $BACKUP_PATH"
        cp "$HOME/.bashrc" "$BACKUP_PATH"
    fi

    print_colored "$YELLOW" "Downloading new .bashrc from $BASHRC_URL"
    if ! curl -fsSL "$BASHRC_URL" -o "$HOME/.bashrc"; then
        print_colored "$RED" "Failed to download .bashrc."
        exit 1
    fi

    print_colored "$GREEN" ".bashrc successfully updated."
    print_colored "$BLUE" "Run 'source ~/.bashrc' or restart your terminal to apply changes."
}

# --- Main ---
main() {
    print_colored "$BLUE" "Starting workstation setup..."

    detect_pkg_manager
    install_dependencies
    install_fastfetch
    install_font
    install_starship_and_fzf
    set_starship_preset
    copy_bashrc

    print_colored "$GREEN" "Workstation setup completed successfully!"
}

main "$@"
