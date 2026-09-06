#### Kanagawa Lotus palette (hex)
thm_bg="#f2ecbc"      # lotusWhite3
thm_fg="#545464"      # lotusInk1
thm_black="#e7dba0"   # inactive surface
thm_gray="#8a8980"    # muted text
thm_red="#c84053"
thm_green="#6f894e"
thm_yellow="#77713f"
thm_blue="#4d699b"
thm_pink="#624c83"
thm_cyan="#597b75"
thm_orange="#cc6d00"

#### core
set -g status on
set -g status-interval 3

# pane borders
set -g pane-border-style "fg=${thm_gray}"
set -g pane-active-border-style "fg=${thm_blue}"

# messages / command line
set -g message-style "bg=${thm_black},fg=${thm_fg}"
set -g message-command-style "bg=${thm_black},fg=${thm_fg}"

# copy mode match
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

# right: time
set -g status-right "#[fg=${thm_gray}]%Y-%m-%d #[fg=${thm_fg},bold]%H:%M "
