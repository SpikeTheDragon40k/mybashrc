## mybashrc & workstation setup

A cross‑distribution Bash environment and workstation bootstrap:

- **`.bashrc`** – Rich, opinionated shell config with:
  - Navigation, listing, archive, and system aliases
  - Sensible history, completion, and prompt behavior
  - Optional integrations (`starship`, `zoxide`, `fzf`, `fastfetch`, `ripgrep`, etc.) that degrade gracefully if missing
- **`setty.sh`** – Distro‑ and installer‑agnostic script that:
  - Detects your package manager (apt/nala, dnf/yum, pacman, zypper, apk, etc.)
  - Installs core CLI tools, fonts, `starship`, `fzf`, and drops in this `.bashrc`
  - Works on Debian/Ubuntu, RHEL/Fedora/Alma/Rocky, Arch, openSUSE, Alpine, and more

Designed to give you a consistent, powerful terminal experience across different Linux distros with minimal manual setup.

***

## Quick start

1. **Clone the repo**

   ```bash
   git clone https://github.com/SpikeTheDragon40k/mybashrc.git "$HOME/mybashrc"
   ```

2. **(Optional but recommended) Run the setup script**

   From the repo directory:

   ```bash
   cd "$HOME/mybashrc"
   chmod +x setty.sh
   ./setty.sh
   ```

   This will:
   - Detect your distro/package manager
   - Install dependencies (tools, fonts, `starship`, `fzf`, etc.)
   - Back up your existing `.bashrc` and install the new one

3. **Reload your shell**

   ```bash
   exec bash
   # or: source ~/.bashrc
   ```


