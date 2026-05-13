#### Tokyo Night Day inspired palette (hex)
thm_bg="#e1e2e7"      # editor background
thm_fg="#3760bf"      # primary deep-blue text
thm_black="#c4c8da"   # selection / inactive blocks
thm_gray="#848cb5"    # muted text / borders
thm_red="#f52a65"
thm_green="#587539"
thm_yellow="#8c6c3e"
thm_blue="#2e7de9"
thm_pink="#9854f1"    # magenta
thm_cyan="#007197"
thm_orange="#b15c00"

#### core
set -g status on
set -g status-interval 3

# pane borders
set -g pane-border-style "fg=${thm_black}"
set -g pane-active-border-style "fg=${thm_blue}"

# messages / command line
set -g message-style "bg=${thm_black},fg=${thm_fg}"
set -g message-command-style "bg=${thm_black},fg=${thm_fg}"

# copy mode match (optional)
set -g mode-style "bg=${thm_black},fg=${thm_fg}"

#### status bar
set -g status-style "bg=${thm_bg},fg=${thm_fg}"
set -g status-left-length 40
set -g status-right-length 120

# left: session name
set -g status-left "#[bg=${thm_blue},fg=${thm_bg},bold] #S #[bg=${thm_bg},fg=${thm_fg}]"

# window list
setw -g window-status-style "bg=${thm_bg},fg=${thm_gray}"
setw -g window-status-current-style "bg=${thm_black},fg=${thm_fg},bold"
setw -g window-status-format " #[fg=${thm_gray}]#I:#W "
setw -g window-status-current-format " #[fg=${thm_fg}]#I:#W "

# right: git/host/time-ish (edit to taste)
set -g status-right "#[fg=${thm_gray}]%Y-%m-%d #[fg=${thm_fg},bold]%H:%M #[fg=${thm_gray}]"
