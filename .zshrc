# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==========================================
# VARIABLES DE ENTORNO
# ==========================================
export EDITOR='nvim'
export VISUAL='nvim'

if [ -d "$HOME/.local/bin" ] ; then
  PATH="$HOME/.local/bin:$PATH"
fi

# ==========================================
# OPTIMIZACIÓN Y CACHÉ DE AUTOCOMPLETADO
# ==========================================
autoload -Uz compinit
local zcompdump="$HOME/.cache/zcompdump"

if [[ -n "$zcompdump"(#qN.mh+24) ]]; then
    compinit -i -d "$zcompdump"
else
    compinit -C -d "$zcompdump"
fi

if [[ ! -f "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc" ]]; then
    zcompile -U "$zcompdump"
fi

autoload -Uz add-zsh-hook
_comp_options+=(globdots)

zstyle ':completion:*' menu select
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' '+r:|[._-]=* r:|=*' '+l:|=*'

# ==========================================
# GESTIÓN DEL HISTORIAL
# ==========================================
HISTFILE=~/.zhistory
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# ==========================================
# OPCIONES GENERALES ZSH
# ==========================================
setopt AUTOCD              # Cambiar de directorio sin escribir 'cd'
setopt PROMPT_SUBST        # Habilitar variables en el prompt
setopt MENU_COMPLETE       # Resaltar primer elemento en menú de completado
setopt LIST_PACKED         # Menú más compacto
setopt AUTO_LIST           # Mostrar opciones ambiguas automáticamente
setopt COMPLETE_IN_WORD    # Autocompletar desde cualquier lado de la palabra

# Indicador visual rojo (...) mientras autocompleta
expand-or-complete-with-dots() {
  echo -n "\e[31m…\e[0m"
  zle expand-or-complete
  zle redisplay
}
zle -N expand-or-complete-with-dots
bindkey "^I" expand-or-complete-with-dots

# ==========================================
# ATAJOS DE TECLADO (Bindkeys)
# ==========================================
bindkey '^[[3~' delete-char      # Tecla Suprimir (Del)
bindkey "^[[H" beginning-of-line # Tecla Inicio (Home)
bindkey "^[[F" end-of-line       # Tecla Fin (End)

# ==========================================
# PLUGINS MULTIPLATAFORMA (Arch / Debian / macOS)
# ==========================================
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    # Arch Linux
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    # Debian / Kali / Ubuntu
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif command -v brew &> /dev/null; then
    # macOS (Homebrew)
    source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ==========================================
# ALIASES Y REMPLAZOS MODERNOS
# ==========================================
# Cargar configuraciones de eza y bat desde archivos externos
[[ -f "$HOME/.eza.plugin.zsh" ]] && source "$HOME/.eza.plugin.zsh"
[[ -f "$HOME/.bat.plugin.zsh" ]] && source "$HOME/.bat.plugin.zsh"

alias clip="xclip -sel clip"
alias mirrors="sudo reflector --verbose --latest 5 --country 'United States' --age 6 --sort rate --save /etc/pacman.d/mirrorlist"
alias update="paru -Syu --nocombinedupgrade"
alias grub-update="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias music="ncmpcpp"

# ==========================================
# TÍTULO DE LA VENTANA (Terminal)
# ==========================================
function xterm_title_precmd () {
    print -Pn -- '\e]2;%n@%m %~\a'
    [[ "$TERM" == 'screen'* ]] && print -Pn -- '\e_\005{g}%n\005{-}@\005{m}%m\005{-} \005{B}%~\005{-}\e\\'
}

function xterm_title_preexec () {
    print -Pn -- '\e]2;%n@%m %~ %# ' && print -n -- "${(q)1}\a"
    [[ "$TERM" == 'screen'* ]] && { print -Pn -- '\e_\005{g}%n\005{-}@\005{m}%m\005{-} \005{B}%~\005{-} %# ' && print -n -- "${(q)1}\e\\"; }
}

if [[ "$TERM" == (kitty*|alacritty*|tmux*|screen*|xterm*) ]]; then
    add-zsh-hook -Uz precmd xterm_title_precmd
    add-zsh-hook -Uz preexec xterm_title_preexec
fi

# ==========================================
# POWERLEVEL10K (Debe ir siempre al final)
# ==========================================
source ~/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
