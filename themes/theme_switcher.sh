#!/bin/bash

THEME_FILE="$HOME/.config/themes/current_theme"

# Available themes
THEMES=("solarized-dark" "quietlight" "gruvbox")

# Get current theme
get_current_theme() {
  if [ -f "$THEME_FILE" ]; then
    cat "$THEME_FILE"
  else
    echo "solarized-dark" > "$THEME_FILE"
    echo "solarized-dark"
  fi
}

# Set theme for all applications
set_theme() {
  local theme="$1"
  echo "$theme" > "$THEME_FILE"
  
  # Apply to Neovim (via temporary file that Neovim watches)
  echo "$theme" > "$HOME/.config/nvim/current_theme"
  
  # Apply to tmux
  if tmux info &> /dev/null; then
    case "$theme" in
      "solarized-dark")
        tmux source-file "$HOME/.config/themes/tmux/solarized-dark.tmux"
        ;;
      "gruvbox")
        tmux source-file "$HOME/.config/themes/tmux/gruvbox.tmux"
        ;;
      "quietlight")
        tmux source-file "$HOME/.config/themes/tmux/quietlight.tmux"
        ;;
    esac
  fi
  
  # Apply to fzf
  case "$theme" in
    "solarized-dark")
      echo "Switch fzf theme to solarized dark"
      # Write to a file that will be sourced by .zshrc
      cat "$HOME/.config/themes/fzf/solarized-dark.sh" > "$HOME/.config/themes/current_fzf_theme"
      # Also apply to current shell
      source "$HOME/.config/themes/fzf/solarized-dark.sh"
      ;;
    "gruvbox")
      echo "Switch fzf theme to gruvbox"
      # Write to a file that will be sourced by .zshrc
      cat "$HOME/.config/themes/fzf/gruvbox.sh" > "$HOME/.config/themes/current_fzf_theme"
      # Also apply to current shell
      source "$HOME/.config/themes/fzf/gruvbox.sh"
      ;;
    "quietlight")
      echo "Switch fzf theme to quietlight"
      # Write to a file that will be sourced by .zshrc
      cat "$HOME/.config/themes/fzf/quietlight.sh" > "$HOME/.config/themes/current_fzf_theme"
      # Also apply to current shell
      source "$HOME/.config/themes/fzf/quietlight.sh"
      ;;
    *)
      # Default case for unhandled themes
      echo "No specific FZF theme for $theme"
      ;;
  esac

  # Apply to lazygit
  case "$theme" in
    "solarized-dark")
      echo "Switch lazygit theme to solarized dark"
      cp "$HOME/.config/lazygit/config.solarized-dark.yml" "$HOME/.config/lazygit/config.yml"
      ;;
    "gruvbox")
      echo "Switch lazygit theme to gruvbox"
      cp "$HOME/.config/lazygit/config.gruvbox.yml" "$HOME/.config/lazygit/config.yml"
      ;;
    "quietlight")
      echo "Switch lazygit theme to quietlight"
      cp "$HOME/.config/lazygit/config.quietlight.yml" "$HOME/.config/lazygit/config.yml"
      ;;
    *)
      # Default case for unhandled themes
      echo "No specific lazygit theme for $theme"
      ;;
  esac
  
  # Apply to kitty
  case "$theme" in
    "gruvbox")
      echo "Switch kitty theme to gruvbox"
      cp "$HOME/.config/kitty/themes/gruvbox-dark-soft.conf" "$HOME/.config/kitty/current_theme.conf"
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/gruvbox-dark-soft.conf" 2>/dev/null
      ;;
    "quietlight")
      echo "Switch kitty theme to quietlight"
      cp "$HOME/.config/kitty/themes/quiet-light.conf" "$HOME/.config/kitty/current_theme.conf"
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/quiet-light.conf" 2>/dev/null
      ;;
    *)
      echo "No specific kitty theme for $theme"
      ;;
  esac

  # For iTerm2, load a Color Preset (does NOT change the profile)
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    case "$theme" in
      "solarized-dark")
        # preset name must match iTerm2's Colors > Color Presets menu item text
        printf '\033]1337;SetColors=preset=Solarized Dark Custom\a' > /dev/tty
        ;;
      "quietlight")
        printf '\033]1337;SetColors=preset=Quiet Light\a' > /dev/tty
        ;;
    esac
  fi
  
  echo "Theme switched to $theme"
}

# List available themes
list_themes() {
  echo "Available themes:"
  for theme in "${THEMES[@]}"; do
    echo "  $theme"
  done
}

# Switch to the next theme in rotation
next_theme() {
  current=$(get_current_theme)
  
  # Find current index
  index=0
  for i in "${!THEMES[@]}"; do
    if [[ "${THEMES[$i]}" = "${current}" ]]; then
      index=$i
      break
    fi
  done
  
  # Calculate next index
  next_index=$(( (index + 1) % ${#THEMES[@]} ))
  set_theme "${THEMES[$next_index]}"
}

# Command processing
case "$1" in
  "set")
    if [ -z "$2" ]; then
      echo "Please specify a theme to set"
      list_themes
      exit 1
    fi
    set_theme "$2"
    ;;
  "get")
    get_current_theme
    ;;
  "list")
    list_themes
    ;;
  "next")
    next_theme
    ;;
  *)
    echo "Usage: theme_switcher.sh [command] [args]"
    echo "Commands:"
    echo "  set [theme]  - Set specific theme"
    echo "  get          - Get current theme"
    echo "  list         - List available themes"
    echo "  next         - Switch to next theme in rotation"
    list_themes
    ;;
esac
