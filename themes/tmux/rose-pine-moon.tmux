#### Rosé Pine Moon palette (hex)
thm_bg="#232136"      # base
thm_fg="#e0def4"      # text
thm_black="#44415a"   # highlight medium
thm_gray="#908caa"    # subtle text
thm_red="#eb6f92"     # love
thm_green="#3e8fb0"   # pine
thm_yellow="#f6c177"  # gold
thm_blue="#9ccfd8"    # foam
thm_pink="#c4a7e7"    # iris
thm_cyan="#ea9a97"    # rose
thm_orange="#ea9a97"  # rose (warm accent)

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
