[ -f /opt/homebrew/share/autojump/autojump.fish ]; and source /opt/homebrew/share/autojump/autojump.fish

export BAT_THEME="gruvbox-dark"
export EDITOR=nvim
export VISUAL=nvim

# alias
alias ls exa
alias src 'source ~/.config/fish/config.fish'
alias cat bat
alias vi nvim
alias a ls
alias c clear
alias ll 'exa -lga --git --icons'
alias su 'su -m'
alias df 'df -h'
alias du 'du -h -d 2'
alias tf 'tail -f'
alias npm pnpm

# common directories
alias wk 'cd ~/workspace' alias home 'cd ~'
alias dl 'cd ~/Downloads'
alias github 'cd ~/github'

# alias git
alias g git
alias gd 'git diff'
alias gc 'git clean'
alias gdc 'git diff --cached'
alias gco 'git checkout'
alias gre 'git reset'
alias greh 'git reset --hard'
alias gres 'git reset --soft'
alias gcm 'git commit -m'
alias gca 'git commit --amend'
alias gp 'git push'
alias gl 'git pull'
alias glr 'git pull --reabse'
alias gri 'git rebase -i'
alias gst 'git status'

# alias cd
alias cd.. 'cd ..'
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias ..... 'cd ../../../..'

# alias file
alias md 'mkdir -p'
alias yd yt-dlp

rvm default
