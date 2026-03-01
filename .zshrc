#######################################
# EXPORTS
#######################################

export SRC="$HOME/.tilde/src"
export ZSH_LIB="$HOME/.tilde/lib/zsh"

export PATH="$HOME/.tilde/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

eval "$(/opt/homebrew/bin/brew shellenv)"

export HOMEBREW_BUNDLE_FILE="$HOME/.brew/Brewfile"
export GH_CONFIG_DIR="$HOME/.github"

export HISTFILE="$HOME/.shell/.zsh_history"
export SHELL_SESSIONS_DIR="$HOME/.shell/sessions"

export EDITOR="cursor --wait"
export VISUAL="cursor --wait"

#######################################
# ALIASES
#######################################

alias cp='cp -i'
alias ls='ls -aF'
alias mkdir='mkdir -p'
alias mv='mv -i'
alias ping='ping -c 10'
alias rm='rm -iv'
alias sha='shasum -256'

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

#######################################
# FUNCTIONS
#######################################

function coffee() {
  /usr/bin/caffeinate -dims -t "${1:-3600}"
}

function jump() {
  [[ -d "$1" ]] && [[ -o interactive ]] && cd "$1" || open "$1"
}

function mkcd() {
    mkdir -p $@ && cd ${@:$#}
}

function pcp() {
  printf "%s\n" "$1" | tee >(tr -d '\n' | pbcopy)
}

#######################################
# COMPLETIONS
#######################################

autoload -Uz compinit && compinit -d "$HOME/.shell/.zcompdump"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

#######################################
# SETUP
#######################################

for lib in "${ZSH_LIB}"/*; do
  # shellcheck source=./.tilde/lib/zsh
  [ -d "${lib}" ] || source "${lib}"
done

[ -n "$ZSH_VERSION" ] && \
  precmd_functions+=(echo -ne "\033]0;/${PWD##*/}/\007")
  