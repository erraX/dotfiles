#### Everforest Light Medium palette (hex)
thm_bg="#fdf6e3"
thm_fg="#5c6a72"
thm_black="#f4f0d9"
thm_gray="#708089"
thm_red="#ad3b4a"
thm_green="#47661b"
thm_yellow="#8c5a00"
thm_blue="#2e7099"
thm_pink="#8f537f"
thm_cyan="#2c7459"
thm_orange="#9a5200"

#### core
set -g status on
set -g status-interval 3

# pane borders
set -g pane-border-style "fg=#829181"
set -g pane-active-border-style "fg=${thm_blue}"

# messages / command line
set -g message-style "bg=${thm_black},fg=${thm_fg}"
set -g message-command-style "bg=${thm_black},fg=${thm_fg}"

# copy mode match
set -g mode-style "bg=#eaedc8,fg=${thm_fg}"

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
