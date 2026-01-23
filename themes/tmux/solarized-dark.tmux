#### solarized-dark palette (hex)
thm_bg="#002b36"     # base03
thm_fg="#839496"     # base0
thm_black="#073642"  # base02 (selection / surfaces)
thm_gray="#586e75"   # base01 (muted text)
thm_red="#dc322f"    # red
thm_green="#859900"  # green
thm_yellow="#b58900" # yellow
thm_blue="#268bd2"   # blue
thm_pink="#6c71c4"   # violet
thm_cyan="#2aa198"   # cyan
thm_orange="#cb4b16" # orange

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
