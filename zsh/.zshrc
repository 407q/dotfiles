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

function zle-line-init() {
  emulate -L zsh
  [[ $CONTEXT == start ]] || return 0

  while true; do
    zle .recursive-edit
    local -i ret=$?
    [[ $ret == 0 && $KEYS == $'\4' ]] || break
    [[ -o ignore_eof ]] || exit 0
  done

  local saved_prompt=$PROMPT
  local saved_rprompt=$RPROMPT
  PROMPT='%F{#86BBD8}❯%f '
  RPROMPT=''
  zle .reset-prompt
  PROMPT=$saved_prompt
  RPROMPT=$saved_rprompt

  if (( ret )); then
    zle .send-break
  else
    zle .accept-line
  fi
  return ret
}
zle -N zle-line-init

eval "$(sheldon --profile late source)"

#zprof #debug
