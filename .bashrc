#!/usr/bin/env bash
# shellcheck shell=bash

#######################################################
# SOURCED ALIASES AND SCRIPTS BY zachbrowne.me
#######################################################

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
elif [ -f /etc/bash.bashrc ]; then
    . /etc/bash.bashrc
fi

# Everything below only matters for interactive shells (keeps scp/rsync/scripts clean)
[[ $- != *i* ]] && return

# ble.sh must be loaded early and attached at the very end of this file
if [ -f /usr/share/blesh/ble.sh ]; then
    source /usr/share/blesh/ble.sh --noattach
elif [ -f "$HOME/.local/share/blesh/ble.sh" ]; then
    source "$HOME/.local/share/blesh/ble.sh" --noattach
fi

if command -v fastfetch &> /dev/null; then
    fastfetch
fi

# Enable bash programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

#######################################################
# EXPORTS
#######################################################

# Disable the bell
bind "set bell-style visible"

# Expand the history size
export HISTFILESIZE=50000
export HISTSIZE=20000
export HISTTIMEFORMAT="%F %T " # add timestamp to history

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Check the window size after each command and, if necessary, update the values of LINES and COLUMNS
shopt -s checkwinsize

# Causes bash to append to history instead of overwriting it so if you start a new terminal, you have old session history
# (keeps whatever /etc/bashrc already put in PROMPT_COMMAND, e.g. VTE's "open tab in same dir")
shopt -s histappend
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# set up XDG folders
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# PATH helpers: only add existing dirs, never add duplicates when re-sourcing
path_prepend() { [ -d "$1" ] && case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
path_append() { [ -d "$1" ] && case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac; }
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.fzf/bin"
path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.local/bin"
path_append "/var/lib/flatpak/exports/bin"
path_append "$XDG_DATA_HOME/flatpak/exports/bin"
export PATH
unset -f path_prepend path_append

# Allow ctrl-S for history navigation (with ctrl-R)
stty -ixon 2>/dev/null

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
bind "set completion-ignore-case on"

# Show auto-completion list automatically, without double tab
bind "set show-all-if-ambiguous On"

# Set the default editor: nano or micro.
# Keeps $EDITOR if it's already one of them (e.g. "export EDITOR=micro" in ~/.profile),
# otherwise uses nano, then micro.
my_editor=""
case "${EDITOR##*/}" in
    nano|micro) command -v "$EDITOR" &> /dev/null && my_editor="${EDITOR##*/}" ;;
esac
if [ -z "$my_editor" ]; then
    for e in nano micro; do
        if command -v "$e" &> /dev/null; then
            my_editor="$e"
            break
        fi
    done
    unset e
fi
if [ -n "$my_editor" ]; then
    export EDITOR="$my_editor"
    export VISUAL="$my_editor"
    alias vim="$my_editor"
    alias vi="$my_editor"
    alias svi="sudo $my_editor"
fi
unset my_editor
command -v nano &> /dev/null && alias snano='sudo nano'
command -v micro &> /dev/null && alias smicro='sudo micro'

# Colors for ls and grep (GNU uses dircolors, BSD/macOS uses CLICOLOR)
export CLICOLOR=1
if command -v dircolors &> /dev/null; then
    eval "$(dircolors -b)"
fi
if ls --color=auto / &> /dev/null; then
    LS_COLOR_FLAG='--color=auto'
else
    LS_COLOR_FLAG='-G'
fi
alias grep='grep --color=auto'

#######################################################
# ALIASES
#######################################################

# ripgrep shortcuts (grep stays grep: rg is not a drop-in replacement)
if command -v rg &> /dev/null; then
    alias rgi='rg -i'
    alias rga='rg --hidden --glob "!.git"'
    alias rgf='rg --files --hidden --glob "!.git"'
fi

# bat is called batcat on Debian/Ubuntu
if ! command -v bat &> /dev/null && command -v batcat &> /dev/null; then
    alias bat='batcat'
fi
if command -v bat &> /dev/null || command -v batcat &> /dev/null; then
    alias cat='bat --paging=never'
fi

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
if command -v notify-send &> /dev/null; then
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
fi

# Edit this .bashrc file
alias ebrc='${EDITOR:-nano} ~/.bashrc'

# Show help for this .bashrc file
if [ -f ~/.bashrc_help ]; then
    alias hlp='less ~/.bashrc_help'
fi

# alias to show the date
alias da='date "+%Y-%m-%d %A %T %Z"'

# aliases to modified commands
alias cp='cp -i'
alias mv='mv -i'
if command -v trash &> /dev/null; then
    alias rm='trash -v'
else
    alias rm='rm -i' # fallback to interactive remove
fi
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias less='less -R'
alias cls='clear'
command -v apt-get &> /dev/null && alias apt-get='sudo apt-get'
command -v multitail &> /dev/null && alias multitail='multitail --no-repeat -c'
command -v freshclam &> /dev/null && alias freshclam='sudo freshclam'

# Change directory aliases
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# aliases for multiple directory listing commands
alias ls="ls -aFh $LS_COLOR_FLAG"  # add colors and file type extensions
alias la='ls -Alh'                 # show hidden files
alias lx='ls -lXBh'                # sort by extension
alias lk='ls -lSrh'                # sort by size
alias lc='ls -ltcrh'               # sort by change time
alias lu='ls -lturh'               # sort by access time
alias lr='ls -lRh'                 # recursive ls
alias lt='ls -ltrh'                # sort by date
alias lm='ls -alh | less'          # pipe through 'less'
alias lw='ls -xAh'                 # wide listing format
alias ll='ls -Fls'                 # long listing format
alias labc='ls -lap'               # alphabetical sort
alias lf="command ls -l | grep -v '^d'" # files only
alias ldir="command ls -l | grep '^d'"  # directories only
alias lla='ls -Al'                 # List and Hidden Files
alias las='ls -A'                  # Hidden Files
alias lls='ls -l'                  # List
unset LS_COLOR_FLAG

# alias chmod commands
alias mx='chmod a+x'

# Search command line history
alias h="history | grep -i "

# Search running processes
alias p="command ps aux | grep -i "
alias topcpu="command ps -eo pcpu,pid,user,args --sort=-pcpu | head -11"

# Search files in the current folder
alias f="find . | grep -i "

# Count all files (recursively) in the current folder
alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"

# To see if a command is aliased, a file, or a built-in command
alias checkcommand="type -t"

# Show open ports
alias openports='sudo ss -tulpn'

# aliases for safe and forced reboots
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo systemctl reboot -i' # ignore inhibitors (apps blocking shutdown)

# aliases to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r | less"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# aliases for archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# Show all logs in /var/log, or the systemd journal
alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"
if command -v journalctl &> /dev/null; then
    alias jlog='sudo journalctl -f'           # follow the journal
    alias jerr='journalctl -b -p err --no-pager' # errors since boot
fi

#######################################################
# HYBRID GRAPHICS (AMD iGPU + NVIDIA dGPU)
#######################################################

if command -v nvidia-smi &> /dev/null; then
    # Run a program on the NVIDIA dGPU (most distros ship prime-run, this is the fallback)
    if ! command -v prime-run &> /dev/null; then
        prime-run() {
            __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia "$@"
        }
    fi

    # Is the dGPU asleep? Reads sysfs only, so it does not wake the GPU like nvidia-smi does
    dgpu() {
        local d
        for d in /sys/bus/pci/devices/*; do
            [ "$(cat "$d/vendor" 2>/dev/null)" = "0x10de" ] || continue
            case "$(cat "$d/class" 2>/dev/null)" in
                0x03*) echo "${d##*/}: $(cat "$d/power/runtime_status")" ;;
            esac
        done
    }

    # Wakes the dGPU: use when you actually want numbers
    alias gpus='nvidia-smi --query-gpu=name,pstate,power.draw,temperature.gpu,utilization.gpu,memory.used --format=csv'
fi

#######################################################
# INTEGRATIONS
#######################################################

# Bitwarden SSH agent, only when its socket exists (otherwise keep the system agent)
if [ -S "$HOME/.bitwarden-ssh-agent.sock" ]; then
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
fi

if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
    alias cd='z'
    # Bind Ctrl+f to insert 'zi' followed by a newline
    bind '"\C-f":"zi\n"'
fi

# fzf key bindings (Ctrl-R history, Ctrl-T files, Alt-C cd)
if command -v fzf &> /dev/null; then
    if [[ ${BLE_VERSION-} ]] && ((${_ble_version:-0} >= 400)); then
        # ble.sh >= 0.4 has its own fzf integration
        ble-import -d integration/fzf-completion
        ble-import -d integration/fzf-key-bindings
    else
        # fzf's script binds emacs-editing-mode/vi-editing-mode (Ctrl-Z mode toggle),
        # which older ble.sh doesn't support: drop those lines
        if fzf --bash &> /dev/null; then
            eval "$(fzf --bash | grep -v 'editing-mode')"
        else
            # fzf < 0.48 (e.g. Ubuntu 24.04, Debian 12)
            for fzf_file in \
                /usr/share/doc/fzf/examples/key-bindings.bash \
                /usr/share/fzf/key-bindings.bash \
                /usr/share/fzf/shell/key-bindings.bash \
                "$HOME/.fzf/shell/key-bindings.bash"; do
                if [ -f "$fzf_file" ]; then
                    eval "$(grep -v 'editing-mode' "$fzf_file")"
                    break
                fi
            done
            unset fzf_file
        fi
    fi
fi

# Machine-specific settings that should not live in the repo
if [ -f "$HOME/.bashrc.local" ]; then
    . "$HOME/.bashrc.local"
fi

# Must be the last line
[[ ${BLE_VERSION-} ]] && ble-attach
