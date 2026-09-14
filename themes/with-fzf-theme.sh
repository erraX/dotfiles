#!/bin/sh
# Launch a tool with the current fzf theme, not stale colors inherited from a
# long-running Herdr server. Keep a stable layout and load only today's colors.
# Usage: with-fzf-theme.sh command [args...]
set -eu

if [ "$#" -eq 0 ]; then
  printf 'Usage: with-fzf-theme.sh command [args...]\n' >&2
  exit 2
fi

# These neutral layout options match the shell's existing fzf presentation.
# Starting fresh also removes old gutter/query/selection colors that may not
# be explicitly overridden by the newly selected theme.
FZF_DEFAULT_OPTS='--highlight-line --info=inline-right --ansi --layout=reverse --border=none'
export FZF_DEFAULT_OPTS
unset FZF_DEFAULT_OPTS_FILE

theme_file="$HOME/.config/themes/current_fzf_theme"
if [ -f "$theme_file" ]; then
  . "$theme_file"
fi

# Preserve the focused pane's cwd, arguments and exit status. No extra popup.
exec "$@"
