# export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# # # # Lines configured by zsh-newuser-install
# HISTFILE=~/.histfile
# HISTSIZE=1000
# SAVEHIST=1000
# bindkey -v
# # End of lines configured by zsh-newuser-install
# # The following lines were added by compinstall
# zstyle :compinstall filename '/home/divy/.zshrc'

# autoload -Uz compinit
# compinit
# # # # End of lines added by compinstall
# source <(oh-my-posh init zsh --config ~/.cache/oh-my-posh/themes/paradox.omp.json)
# source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# [ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh
# [ -f /usr/share/fzf/shell/completion.zsh ] && source /usr/share/fzf/shell/completion.zsh

#####################################################################################3

# Enable Zsh completion and autosuggestions
# autoload -Uz compinit && compinit
# source $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh


# # History settings
# HISTFILE=~/.histfile
# HISTSIZE=1000
# SAVEHIST=1000
# bindkey -v

# # Completion system
# autoload -Uz compinit
# compinit

# # Oh My Posh theme
# source <(oh-my-posh init zsh --config ~/.cache/oh-my-posh/themes/paradox.omp.json)

# # Plugins
# # Autosuggestions
# [[ -f $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
#   source $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# # Syntax highlighting (make sure installed)
# [[ -f $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
#   source $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

###############################################################################

# ---------------------------
# PATH
# ---------------------------
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

export VISUAL=nvim
export EDITOR=nvim
# ---------------------------
# ZSH Options
# ---------------------------
setopt autocd
setopt globstarshort
setopt extendedglob


# ---------------------------
# History
# ---------------------------
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# ---------------------------
# Keybindings
# ---------------------------
bindkey -v   # vi-style keybindings (normal/insert mode)

# ---------------------------
# Completion
# ---------------------------
autoload -Uz compinit
compinit
zstyle :compinstall filename "$HOME/.zshrc"

# ---------------------------
# Prompt (Oh My Posh)
# ---------------------------
# Change config file/theme if you like
eval "$(oh-my-posh init zsh --config ~/.cache/oh-my-posh/themes/paradox.omp.json)"

eval "$(zoxide init zsh)"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

function ff() {
  clear
  kitten icat -n --place 30x30@0x6 --scale-up --align left /home/divy/.config/fastfetch/cat.gif | fastfetch --logo-width 30 --raw -
}

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey 'x^e' edit-command-line

# ---------------------------
# Aliases
# ---------------------------
alias lg="lazygit"
alias neofetch="fastfetch"
alias hypr="nvim ~/dotfiles/hyprland/.config/hypr/hyprland.conf"
alias nvo="nvim ."
alias cls="clear"
alias ldo="lazydocker"
# alias ff="fastfetch"

# ---------------------------
# Plugins
# ---------------------------
# Autosuggestions (inline grey text)
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting (must be LAST for proper coloring)
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---------------------------
# fzf (fuzzy finder integration)
# ---------------------------
[ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh
[ -f /usr/share/fzf/shell/completion.zsh ] && source /usr/share/fzf/shell/completion.zsh

export PATH="$HOME/.cargo/bin:$PATH"

export PATH=$PATH:/home/divy/.spicetify

# Clear screen first (optional)
clear

# Show kitty image (icat) and run fastfetch
kitten icat -n --place 30x30@0x6 --scale-up --align left /home/divy/.config/fastfetch/cat.gif | fastfetch --logo-width 30 --raw -

# Greeting
# figlet Welcome Divy | lolcat

# bun completions
[ -s "/home/divy/.bun/_bun" ] && source "/home/divy/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"


# Linux Activity Tracker Hook
source "/home/divy/code/web/Projects/linux-activity-tracker/shell-hooks/zsh-hook.sh"

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"
