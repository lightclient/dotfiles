# ZSH configuration
PROMPT="%~ $ "
EDITOR="nvim"
DEV_WORKSPACE=~/dev
PATH=$HOME/.bin:$PATH

# History (https://unix.stackexchange.com/questions/273861/unlimited-history-in-zsh)
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

# vim mode (https://dougblack.io/words/zsh-vi-mode.html)
bindkey -v
bindkey -M viins '^J' vi-cmd-mode

bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

# search history with up & down keys
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^P" up-line-or-beginning-search # Up
bindkey "^N" down-line-or-beginning-search # Down

bindkey -s "^[[A" "\a"
bindkey -s "^[[B" "\a"

function zle-line-init zle-keymap-select {
    VIM_PROMPT="%{$fg_bold[yellow]%} [% NORMAL]%  %{$reset_color%}"
    RPS1="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/} $EPS1"
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select
export KEYTIMEOUT=1

if command -v nvim > /dev/null; then
	alias vim=nvim
	alias vi=nvim
fi

# rust config
export PATH="$HOME/.cargo/bin:$PATH"

# preserve current environment when sudoing
alias sudo='sudo -E'

# get pubilc ip address
alias whatsmyip='curl ifconfig.me'

if command -v exa > /dev/null; then
	alias l='exa'
	alias ll='exa'
	alias ll='exa -l'
	alias la='exa -lag'
else
	alias l='ls'
	alias ll='ls'
	alias ll='ls -l'
	alias la='ls -la'
fi

# use rg instead of grep for fzf
if command -v rg > /dev/null; then
  export FZF_DEFAULT_COMMAND=$'rg --files --hidden --glob '!.git''
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# set gpg agent
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
# echo UPDATESTARTUPTTY | gpg-connect-agent

# golang config
export GOPATH=$DEV_WORKSPACE/go-workspace # don't forget to change your path correctly!
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOPATH/bin

# pyenv config
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
fi

# tmux config
alias tmux="tmux -u"

# nvm config
case `uname` in
  Darwin)
    export NVM_DIR="$HOME/.nvm"
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

    HOMEBREW_NO_ENV_HINTS=1
  ;;
  Linux)
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  ;;
esac

export TERM=xterm-256color

eval "$(starship init zsh)"

<<<<<<< HEAD
# The following lines were added by compinstall
zstyle :compinstall filename '/home/matt/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

export PATH="$PATH:/Users/matt/.foundry/bin"
