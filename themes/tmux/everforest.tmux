#### Everforest dark medium palette (hex)
thm_bg="#2d353b"      # bg0
thm_fg="#d3c6aa"      # fg
thm_black="#343f44"   # bg1 (selection / surfaces)
thm_gray="#859289"    # grey1 (muted text)
thm_red="#e67e80"     # red
thm_green="#a7c080"   # green
thm_yellow="#dbbc7f"  # yellow
thm_blue="#7fbbb3"    # blue
thm_pink="#d699b6"    # purple
thm_cyan="#83c092"    # aqua
thm_orange="#e69875"  # orange

#### core
set -g status on
set -g status-interval 3

# pane borders
set -g pane-border-style "fg=${thm_black}"
set -g pane-active-border-style "fg=${thm_blue}"

# messages / command line
set -g message-style "bg=${thm_black},fg=${thm_fg}"
set -g message-command-style "bg=${thm_black},fg=${thm_fg}"

# copy mode match
set -g mode-style "bg=${thm_green},fg=${thm_bg}"

#### status bar
set -g status-style "bg=${thm_bg},fg=${thm_fg}"
set -g status-left-length 40
set -g status-right-length 120

# left: session name
set -g status-left "#[bg=${thm_green},fg=${thm_bg},bold] #S #[bg=${thm_bg},fg=${thm_fg}]"

# window list
setw -g window-status-style "bg=${thm_bg},fg=${thm_gray}"
setw -g window-status-current-style "bg=${thm_black},fg=${thm_fg},bold"
setw -g window-status-format " #[fg=${thm_gray}]#I:#W "
setw -g window-status-current-format " #[fg=${thm_fg}]#I:#W "

# right: time
set -g status-right "#[fg=${thm_gray}]%Y-%m-%d #[fg=${thm_fg},bold]%H:%M "
