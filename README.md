## mybashrc

A cross‑distribution, “batteries‑included” `.bashrc` focused on:

- Rich, opinionated aliases for navigation, listing, archives, logs, and system inspection  
- Sensible history, completion, and prompt behavior (with `starship` and `zoxide`)  
- Optional integrations (`fastfetch`, `ripgrep`, `trash-cli`, etc.) that degrade gracefully if missing  

Designed to work on Debian/Ubuntu, RHEL/Fedora/Alma/Rocky, Arch, and others with minimal assumptions about package availability.

***

## Quick setup

1. **Clone or download**

   ```bash
   git clone https://github.com/SpikeTheDragon40k/mybashrc.git "$HOME/mybashrc"
   ```

2. **Backup your current `.bashrc`**

   ```bash
   cp ~/.bashrc ~/.bashrc.backup."$(date +%Y%m%d%H%M%S)"
   ```

3. **Install the new `.bashrc`**

   ```bash
   ln -sf "$HOME/mybashrc/.bashrc" "$HOME/.bashrc"
   # or, if you prefer copying:
   # cp "$HOME/mybashrc/.bashrc" "$HOME/.bashrc"
   ```

4. **Reload your shell**

   ```bash
   exec bash
   # or: source ~/.bashrc
   ```
