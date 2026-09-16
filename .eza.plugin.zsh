alias ls="eza -F -gh --group-directories-first --git ${EZA_GIT_IGNORE} --icons --color-scale all --hyperlink"
alias lh='ls -d .*'
alias lD='ls -D'
alias lc='ls -1'

alias l='ls -l --group-directories-first'
alias ll='ls -lh --group-directories-first'
alias la='l -a --group-directories-first'
alias lla='ll -a --group-directories-first'

if [[ "$EZA_ENABLE_SORT_ALIASES" = 1 ]]; then
  alias lA='ll --sort=acc'
  alias lC='ll --sort=cr'
  alias lM='ll --sort=mod'
  alias lS='ll --sort=size'
  alias lX='ll --sort=ext'
  alias llm='lM'
fi

if [[ "$EZA_ENABLE_EXTENDED_ALIASES" = 1 ]]; then
  alias l='la -a'
  alias lsa='l'
  alias lx='l -HimUuS'
  alias lxa='lx -Z@'
fi

alias lt='ls -T'
alias tree=lt

return 1
