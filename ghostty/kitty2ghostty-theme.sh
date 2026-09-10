#!/usr/bin/env bash
# Convert kitty theme .conf files into Ghostty theme files.
# Usage: ./kitty2ghostty-theme.sh [kitty-themes-dir] [ghostty-themes-dir]
set -euo pipefail

src="${1:-$(dirname "$0")/../kitty/themes}"
dst="${2:-$(dirname "$0")/themes}"
mkdir -p "$dst"

for f in "$src"/*.conf; do
  name="$(basename "$f" .conf)"
  out="$dst/$name"
  {
    echo "# Converted from kitty/themes/$name.conf"
    awk '
      /^#/ || NF < 2 { next }
      $1 == "foreground"            { print "foreground = " $2; next }
      $1 == "background"            { print "background = " $2; next }
      $1 == "selection_foreground"  { print "selection-foreground = " $2; next }
      $1 == "selection_background"  { print "selection-background = " $2; next }
      $1 == "cursor"                { print "cursor-color = " $2; next }
      $1 == "cursor_text_color"     { if ($2 != "background") print "cursor-text = " $2; next }
      $1 ~ /^color[0-9]+$/          { sub(/^color/, "", $1); print "palette = " $1 "=" $2; next }
    ' "$f"
  } > "$out"
  echo "wrote $out"
done
