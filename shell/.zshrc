# ==============================================================================
# Core Settings
# ==============================================================================

export LANG="en_US.UTF-8"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R -F -X"
export MANPAGER="nvim +Man!"

# ==============================================================================
# PATH
# ==============================================================================

PATH="$HOME/.local/bin:$PATH"
PATH="$HOME/.scripts:$PATH"
PATH="$HOME/.cargo/bin:$PATH"                       # Rust
PATH="$HOME/.foundry/bin:$PATH"                     # Foundry


export PATH

# ==============================================================================
# History  (https://unix.stackexchange.com/questions/273861)
# ==============================================================================

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000000
SAVEHIST=10000000
HISTORY_IGNORE="(l|ls|ll|la|cd|pwd|exit|cd ..)"

setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY               # Don't execute immediately upon history expansion.
setopt HIST_BEEP                 # Beep when accessing nonexistent history.
setopt AUTO_CD                   # Type a directory name to cd into it.
setopt GLOB_DOTS                 # Include dotfiles in glob matches and completion.
zstyle ':completion:*' ignored-patterns '.git'

# ==============================================================================
# Vi Mode & Key Bindings  (https://dougblack.io/words/zsh-vi-mode.html)
# ==============================================================================

bindkey -v
export KEYTIMEOUT=1

bindkey -M viins '^J' vi-cmd-mode

bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

# search history with ^P / ^N; disable raw arrow keys
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^P" up-line-or-beginning-search
bindkey "^N" down-line-or-beginning-search
bindkey -s "^[[A" "\a"
bindkey -s "^[[B" "\a"

# show NORMAL indicator in right prompt
function zle-line-init zle-keymap-select {
    VIM_PROMPT="%{$fg_bold[yellow]%} [% NORMAL]%  %{$reset_color%}"
    RPS1="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/} $EPS1"
    zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

# ==============================================================================
# Aliases
# ==============================================================================

# editor
if command -v nvim > /dev/null; then
  alias vim=nvim
  alias vi=nvim
fi

# listing (prefer eza > exa > ls)
if command -v eza > /dev/null; then
  alias ls='eza'
  alias l='eza'
  alias ll='eza -l'
  alias la='eza -lag'
else
  alias l='ls'
  alias ll='ls -l'
  alias la='ls -la'
fi

# bat (better cat)
if command -v bat > /dev/null; then
  alias cat='bat --plain'
fi

alias sudo='sudo -E'                               # preserve environment
alias whatsmyip='curl ifconfig.me'                  # public IP
alias tmux='tmux -u'                                # force UTF-8
alias gpg-unlock='echo | gpg --sign --armor >/dev/null'
alias fix-term='stty sane; tput reset'

# ==============================================================================
# GPG / SSH Agent
# ==============================================================================

if command -v gpgconf > /dev/null; then
  export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  gpgconf --launch gpg-agent

  # keep GPG_TTY fresh — critical for pinentry-curses after tmux reattach
  export GPG_TTY=$(tty)
  _gpg_update_tty() {
    export GPG_TTY=$(tty)
    gpg-connect-agent UPDATESTARTUPTTY /bye >/dev/null 2>&1
  }
  autoload -U add-zsh-hook
  add-zsh-hook preexec _gpg_update_tty
fi

# ==============================================================================
# Language & Tool Managers
# ==============================================================================

# Go ---
export GOPATH="$HOME/.go"
export PATH="$PATH:$GOPATH/bin"



# fnm (fast node manager) ---
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm > /dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Homebrew (macOS) ---
if [ -d /opt/homebrew ]; then
  export HOMEBREW_NO_ENV_HINTS=1
fi

# Ruby (chruby) — macOS via Homebrew ---
if [ -f /opt/homebrew/opt/chruby/share/chruby/chruby.sh ]; then
  source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
  source /opt/homebrew/opt/chruby/share/chruby/auto.sh
  chruby ruby-3.4.1
fi

# ==============================================================================
# FZF
# ==============================================================================

if command -v rg > /dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
fi
if command -v bat > /dev/null; then
  export FZF_CTRL_T_OPTS='--preview "if [ -d {} ]; then eza -la --color=always {} 2>/dev/null || ls -la --color=always {}; else bat --color=always --style=numbers --line-range=:200 {}; fi" --preview-window=right:50%'
fi
export FZF_CTRL_R_OPTS='--no-preview'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ==============================================================================
# Completions & Prompt
# ==============================================================================

# only regenerate completion dump once per day
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# fzf-tab — must be after compinit
[ -f ~/.zsh/fzf-tab/fzf-tab.plugin.zsh ] && source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh

# zoxide (smarter cd)
if command -v zoxide > /dev/null; then
  eval "$(zoxide init zsh)"
fi

# zsh-autosuggestions (fish-like suggestions as you type)
if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# starship prompt
if command -v starship > /dev/null; then
  eval "$(starship init zsh)"
fi


# ==============================================================================
# Bootstrap / Auto-install
# ==============================================================================

# Auto-pull dotfiles (at most once per hour)
_dotfiles_pull() {
  local marker="$HOME/.dotfiles_last_pull"
  local now=$(date +%s)
  local last=0
  [[ -f "$marker" ]] && last=$(cat "$marker")
  if (( now - last > 3600 )); then
    echo "$now" > "$marker"
    {
      before=$(git -C "$HOME/dotfiles" rev-parse HEAD 2>/dev/null)
      git -C "$HOME/dotfiles" -c url.https://github.com/.insteadOf=git@github.com: pull --ff-only --quiet 2>/dev/null
      after=$(git -C "$HOME/dotfiles" rev-parse HEAD 2>/dev/null)
      [[ "$before" != "$after" ]] && echo "dotfiles: updated (${before:0:7}..${after:0:7})"
    } &!
  fi
}
_dotfiles_pull

# ==============================================================================
# Environment Overrides
# ==============================================================================

export TELEPORT_LOGIN=root

# ==============================================================================
# Local / Secrets (keep last — may override anything above)
# ==============================================================================

[ -f ~/.config/secrets.sh ] && source ~/.config/secrets.sh
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
