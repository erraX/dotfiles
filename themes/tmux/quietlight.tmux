#### VS Code "Quiet Light" inspired palette (hex)
thm_bg="#F5F5F5"      # editor background-ish
thm_fg="#333333"      # readable dark text on light bg
thm_black="#E5E5E5"   # light border / inactive blocks
thm_gray="#666666"    # muted text
thm_red="#C91B00"
thm_green="#00C200"
thm_yellow="#C7C400"
thm_blue="#2472C8"
thm_pink="#BC3FBC"    # magenta
thm_cyan="#0FA8CD"
thm_orange="#DAAA01"  # warm accent (close to “yellow/orange”)

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
