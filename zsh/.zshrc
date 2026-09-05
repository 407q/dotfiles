#zmodload zsh/zprof #debug

eval "$(sheldon --profile early source)"

alias removegomi="find . \( -name '.DS_Store' -or -name '._*' \) -delete -print"
alias ls="eza --icons --hyperlink"
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

_evalcache starship init zsh

eval "$(sheldon --profile late source)"

#zprof #debug
