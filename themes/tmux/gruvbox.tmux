#### gruvbox-dark-soft palette (hex)
thm_bg="#32302f"      # bg0 (soft)  <-- requested
thm_fg="#d5c4a1"      # fg1
thm_black="#3c3836"   # bg1 (selection / surfaces)
thm_gray="#a89984"    # fg4 (muted text)
thm_red="#fb4934"     # red
thm_green="#b8bb26"   # green
thm_yellow="#fabd2f"  # yellow
thm_blue="#83a598"    # blue
thm_pink="#d3869b"    # purple
thm_cyan="#8ec07c"    # aqua
thm_orange="#fe8019"  # orange

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

# right: time (edit to taste)
set -g status-right "#[fg=${thm_gray}]%Y-%m-%d #[fg=${thm_fg},bold]%H:%M "
