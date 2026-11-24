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
  - On Arch: installs [`archup`](#archup-arch-updates) and the tools it needs
  - Works on Debian/Ubuntu, RHEL/Fedora/Alma/Rocky, Arch, openSUSE, Alpine, and more
- **`bin/archup`** – Arch update helper: checks for problems before updating repo, AUR and Flatpak packages

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

***

## archup (Arch updates)

`archup` updates repo, AUR (paru, or yay) and Flatpak packages in one go, like Shelly's "update all". The difference is that it collects information and does a dry run first, so it stops before changing anything that would break.

| Command | Alias | Effect |
|---------|-------|--------|
| `archup` | `up` | Check, then update (asks before every change) |
| `archup --check` | `upc` | Report only, changes nothing |
| `archup --mirrors` | `upm` | Refresh the mirrorlist with reflector, then update |

Other flags: `--yes`, `--no-aur`, `--no-flatpak`, `--no-snapshot`. New terminals show how many updates are pending (refreshed in the background every 6 hours).

What it checks and fixes:

- **Before updating:** stale pacman lock, free space on `/` and `/boot`, a `pacman -Syu` dry run, Arch news since your last upgrade, IgnorePkg pins that only cover part of a package set, NVIDIA module packages out of sync with `nvidia-utils`, packages newer than the repos (`-Syuu` only after a clean dry run), packages in no repo and not in the AUR, AUR `-debug` packages, NVIDIA and DKMS modules missing for any installed kernel, and a running kernel whose modules were deleted by an update without a reboot.
- **While updating:** a snapper snapshot (unless snap-pac already takes one), keyrings first, then repos, AUR and Flatpak.
- **After updating:** missing kernel headers, DKMS rebuilds for every kernel (with the build log on failure), GRUB regeneration when kernels change, AUR packages that need a rebuild, `.pacnew` files, orphans, cache trimming (keeps 3 versions for downgrades), failed units, and whether you should reboot.

Packages you build yourself whose name also exists in the AUR: add them to `IgnorePkg` in `/etc/pacman.conf`. paru and yay then never replace them with the AUR version, and archup leaves them out of its AUR updates.

Settings go in `~/.config/archup/archup.conf` (`KEY=value`, parsed, never sourced), for example `EXCLUDE_PKGS=linux-cachyos*` to keep packages you never want out of the checks. Logs are in `~/.local/state/archup/`.

