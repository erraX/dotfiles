export EDITOR="nvim"
export VISUAL="nvim"
export XDG_CONFIG_HOME="$HOME/.config"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n] confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit ice depth=1; zinit light romkatv/powerlevel10k
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab
# zinit light junegunn/fzf-git.sh
zinit snippet OMZP::git
autoload -U compinit && compinit
zinit cdreplay -q

# Run `$(brew --prefix)/opt/fzf/install`
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_COMPLETION_TRIGGER=';;'

alias sth="sh ~/.config/themes/theme_switcher.sh"
alias vi=nvim
alias src='source ~/.zshrc'
alias a=ls
alias c=clear
alias su='su -m'
alias df='df -h'
alias du='du -h -d 2'
alias tf='tail -f'
alias lg='lazygit'
alias kb='kubectl'
alias rm='trash'

# common directories
alias wk='cd ~/workspace'
alias home='cd ~'
alias dl='cd ~/Downloads'
alias github='cd ~/workspace/github'

# alias git
alias g=git
alias gd='git diff'
alias gc='git clean'
alias gdc='git diff --cached'
alias gco='git checkout'
alias gre='git reset'
alias greh='git reset --hard'
alias gres='git reset --soft'
alias gcm='git commit -m'
alias gam='git add -A && git commit -m '
alias gca='git commit --amend'
alias gp='git push'
alias gl='git pull'
alias glr='git pull --rebase'
alias gri='git rebase -i'
alias gst='git status'
alias grmaster='git fetch && git rebase origin/master'
alias gremaster='git fetch && git reset --hard origin/master'

alias main='cd /Users/mni/workspace/booking/main_repo'
alias emfe='cd /Users/mni/workspace/booking/micro-frontends'
alias internal='cd /Users/mni/workspace/booking/micro-frontends/mfes/internal-verification-tool'
alias kyp='cd /Users/mni/workspace/booking/main_repo/projects/kypportal/kypportal-svc'
alias hub='cd ~/workspace/booking/verification-hub/apps/verification-hub-webapp'
alias wkw='cd ~/workspace/booking/verification-hub/apps/verification-workspace-webapp'
alias idvcs='cd ~/workspace/booking/b-mfes-2/component-services/verification-frontend-idv-component-service'


# alias cd
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# alias prez='vi ~/.zpreztorc'
alias zshrc='vi ~/.zshrc'

alias cat='bat'
alias ls='eza'

alias ss='ssh -A ssh.booking.com'
alias snladm='ssh -NL 9211:localhost:9211 mni-adm.dev.booking.com'

alias k='kill -9'


# eval $(thefuck --alias)
# eval "$(zoxide init --cmd cd zsh)"

[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

# source ~/.completion-for-pnpm.zsh

export BAT_THEME="ansi"

# export ENHANCD_COMMAND=cdd
# source ~/.local/share/enhancd/init.sh

# pokemonsay -p Gengar Hello World

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# History auto suggestions
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

bindkey -r '^[c]'
bindkey '^F' fzf-cd-widget

bindkey -r '^[t]'
bindkey '^O' fzf-file-widget

HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_save_no_dups
setopt hist_ignore_dups

# fzf-tab
# export FZF_DEFAULT_OPTS="
#   --color=fg:#3760bf,bg:#e1e2e7,hl:#b15c00 \
#   --color=fg+:#3760bf,bg+:#d5d6db,hl+:#b15c00 \
#   --color=info:#007197,prompt:#9854f1,pointer:#007197 \
#   --color=marker:#9854f1,spinner:#b15c00,header:#587539 \
#   --color=border:#c4c5cf
# "
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
# NOTE: don't use escape sequences (like '%F{red}%d%f') here, fzf-tab will ignore them
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
# preview directory's content with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# custom fzf flags
# NOTE: fzf-tab does not follow FZF_DEFAULT_OPTS by default
zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
# To make fzf-tab follow FZF_DEFAULT_OPTS.
# NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' popup-min-size 50 8
zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
zstyle ':fzf-tab:*' fzf-flags --height=70% --min-height=18 --layout=reverse --border

# bun completions
[ -s "/Users/mni/.bun/_bun" ] && source "/Users/mni/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# export PATH="/opt/homebrew/opt/pnpm@9/bin:$PATH:$HOME/.local/bin"

# Added by Windsurf
export PATH="/Users/mni/.codeium/windsurf/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/mni/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# fnm
FNM_PATH="/opt/homebrew/opt/fnm/bin"
if [ -d "$FNM_PATH" ]; then
  eval "`fnm env`"
fi


# Source current FZF theme
if [ -f "$HOME/.config/themes/current_fzf_theme" ]; then
  source "$HOME/.config/themes/current_fzf_theme"
fi

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# Added by Windsurf
export PATH="/Users/mni/.codeium/windsurf/bin:$PATH"

# export ANTHROPIC_BASE_URL=http://localhost:5000
# export CLAUDE_CODE_USE_BEDROCK=1
# export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1

# For charles proxy debug
# export HTTP_PROXY="http://127.0.0.1:8888"
# export HTTPS_PROXY="http://127.0.0.1:8888"
# export ALL_PROXY="http://127.0.0.1:8888"
# export NO_PROXY="localhost,127.0.0.1"

export VAULT_ADDR="https://vault.booking.com"
