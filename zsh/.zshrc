export LANG=ja_JP.UTF-8
#zmodload zsh/zprof #debug

source ~/zsh/evalcache.plugin.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
_evalcache starship init zsh

typeset -gU path PATH
path+=(
  ~/.yarn/bin
  ~/dotfiles/bin
)
export HOMEBREW_NO_AUTO_UPDATE=1
export DOTS_DIR=~/dotfiles

alias removegomi="find . \( -name '.DS_Store' -or -name '._*' \) -delete -print"
alias ls="eza --icons --hyperlink -T -L=2"
alias vlc='/Applications/VLC.app/Contents/MacOS/VLC'

autoload -Uz compinit
() {
  local dump=~/.zcompdump
  if [[ $dump(#qNmh-24) ]]; then
    compinit -C -d "$dump"
  else
    compinit -d "$dump"
    touch "$dump"
  fi
}
_evalcache gh completion -s zsh

#zprof #debug
