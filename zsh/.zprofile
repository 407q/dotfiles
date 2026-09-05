eval "$(/opt/homebrew/bin/brew shellenv)"
typeset -gU path PATH
path+=(
  ~/.yarn/bin
  ~/dotfiles/bin
  /opt/homebrew/sbin
)
export LANG=ja_JP.UTF-8
export EDITOR="$HOMEBREW_PREFIX/bin/nano"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"
export HOMEBREW_NO_AUTO_UPDATE=1
export DOTS_DIR=~/dotfiles

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
