## mybashrc & workstation setup

A cross‑distribution Bash environment and workstation bootstrap:

- **`.bashrc`** – Rich, opinionated shell config with:
  - Navigation, listing, archive, and system aliases
  - Sensible history, completion, and prompt behavior
  - Optional integrations (`starship`, `zoxide`, `fzf`, `fastfetch`, `ripgrep`, `eza`, etc.) that degrade gracefully if missing
- **`setty.sh`** – Distro‑ and installer‑agnostic script that:
  - Detects your package manager (apt, dnf/yum, pacman, zypper, apk, etc.)
  - Installs core CLI tools, fonts, `starship`, `fzf`, `ble.sh`, and links this `.bashrc`
  - Skips packages your distro doesn't have instead of failing, with fallbacks (official installers, cargo)
  - On laptops: `fwupd`, `nvtop`, Mesa Vulkan/VA-API for the AMD iGPU, power profiles
  - On NVIDIA hybrid laptops (asks first): open kernel driver (needed for RTX 50xx), suspend/power services, `switcheroo-control`
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
   - Back up your existing `.bashrc` and symlink `~/.bashrc` to the repo (so `git pull` updates it)

   Options:

   | Flag | Effect |
   |------|--------|
   | `--gpu` | Install the NVIDIA driver + hybrid graphics setup without asking |
   | `--no-gpu` | Skip the NVIDIA setup (servers, VMs, other machines) |
   | `--copy` | Copy `.bashrc` instead of symlinking it |
   | `-y` | Answer yes to every question |

   Machine-specific settings go in `~/.bashrc.local`, which is sourced automatically.

3. **Reload your shell**

   ```bash
   exec bash
   # or: source ~/.bashrc
   ```

***

## Hybrid graphics helpers

When `nvidia-smi` is available, the `.bashrc` adds:

- `prime-run <app>` – run an app on the NVIDIA dGPU (fallback if your distro doesn't ship it)
- `dgpu` – show whether the dGPU is asleep (`suspended`) without waking it up
- `gpus` – name, power draw, temperature and usage (wakes the dGPU)

