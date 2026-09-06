#### Rosé Pine Dawn palette (hex)
thm_bg="#faf4ed"      # base
thm_fg="#464261"      # current Dawn text
thm_black="#dfdad9"   # highlight medium
thm_gray="#797593"    # subtle text
thm_red="#b4637a"     # love
thm_green="#286983"   # pine
thm_yellow="#9a6700"  # darkened gold for light-background readability
thm_blue="#56949f"    # foam
thm_pink="#907aa9"    # iris
thm_cyan="#d7827e"    # rose
thm_orange="#b66a00"  # darkened warm accent

#### core
set -g status on
set -g status-interval 3

# pane borders
set -g pane-border-style "fg=${thm_black}"
set -g pane-active-border-style "fg=${thm_green}"

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
set -g status-left "#[bg=${thm_green},fg=${thm_bg},bold] #S #[bg=${thm_bg},fg=${thm_fg}]"

# window list
setw -g window-status-style "bg=${thm_bg},fg=${thm_gray}"
setw -g window-status-current-style "bg=${thm_black},fg=${thm_fg},bold"
setw -g window-status-format " #[fg=${thm_gray}]#I:#W "
setw -g window-status-current-format " #[fg=${thm_fg}]#I:#W "

# right: time
set -g status-right "#[fg=${thm_gray}]%Y-%m-%d #[fg=${thm_fg},bold]%H:%M "
