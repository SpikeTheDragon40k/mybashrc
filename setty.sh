#!/bin/sh -e
RC=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
print_colored() {
    printf "${1}%s${RC}\n" "$2"
}
install_fastfetch(){
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch
sudo apt update
sudo nala install -y fastfetch
}
install_dependencies() {
sudo nala install -y curl btop duf git nano bash ripgrep bash-completion tar bat tree multitail wget unzip fontconfig trash-cli zoxide
}

install_font() {
    FONT_NAME="MesloLGS Nerd Font Mono"
    if fc-list :family | grep -iq "$FONT_NAME"; then
        printf "Font '%s' is installed.\n" "$FONT_NAME"
    else
        printf "Installing font '%s'\n" "$FONT_NAME"
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
        FONT_DIR="$HOME/.local/share/fonts"
        if wget -q --spider "$FONT_URL"; then
            TEMP_DIR=$(mktemp -d)
            wget -q $FONT_URL -O "$TEMP_DIR"/"${FONT_NAME}".zip
            unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
            mkdir -p "$FONT_DIR"/"$FONT_NAME"
            mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
            # Update the font cache
            fc-cache -fv
            rm -rf "${TEMP_DIR}"
            printf "'%s' installed successfully.\n" "$FONT_NAME"
        else
            printf "Font '%s' not installed. Font URL is not accessible.\n" "$FONT_NAME"
        fi
    fi
}
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
install_starship_and_fzf() {
    if ! command_exists starship; then
        if ! curl -sS https://starship.rs/install.sh | sh; then
            print_colored "$RED" "Something went wrong during starship install!"
            exit 1
        fi
    else
        printf "Starship already installed\n"
    fi

    if ! command_exists fzf; then
        if [ -d "$HOME/.fzf" ]; then
            print_colored "$YELLOW" "FZF directory already exists. Skipping installation."
        else
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            ~/.fzf/install
        fi
    else
        printf "Fzf already installed\n"
    fi
}
set_starship_preset() {
starship preset pastel-powerline -o ~/.config/starship.toml
}
copy_bashrc() {
BASHRC_URL="https://raw.githubusercontent.com/SpikeTheDragon40k/mybashrc/refs/heads/main/.bashrc"

# Define backup path
BACKUP_PATH="$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)"

# Backup current .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    echo "Backing up current .bashrc to $BACKUP_PATH"
    cp "$HOME/.bashrc" "$BACKUP_PATH"
fi

# Download and replace .bashrc
echo "Downloading new .bashrc from $BASHRC_URL"
curl -fsSL "$BASHRC_URL" -o "$HOME/.bashrc"

# Confirm success
if [ $? -eq 0 ]; then
    echo ".bashrc successfully updated."
    echo "Run 'source ~/.bashrc' or restart your terminal to apply changes."
else
    echo "Failed to download .bashrc."
    exit 1
fi
}
install_dependencies
install_fastfetch
install_font
install_starship_and_fzf
set_starship_preset
copy_bashrc