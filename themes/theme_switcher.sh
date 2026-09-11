#!/bin/bash

THEMES_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
DOTFILES_DIR=$(dirname "$THEMES_DIR")
THEME_FILE="$THEMES_DIR/current_theme"

# Available themes
THEMES=("solarized-dark" "quietlight" "kanagawa-lotus" "rose-pine-dawn" "rose-pine-moon" "gruvbox" "tokyoday" "tokyonight" "everforest" "everforest-light-hard" "everforest-light-medium" "everforest-light-soft")
# Partial profiles: Ghostty (built-in theme), Herdr and Neovim only for now.
THEMES+=("catppuccin-frappe" "nordfox")

is_valid_theme() {
  local requested_theme="$1"
  local theme

  for theme in "${THEMES[@]}"; do
    if [[ "$theme" == "$requested_theme" ]]; then
      return 0
    fi
  done

  return 1
}

write_theme_file() {
  local file="$1"
  local theme="$2"
  local temp_file

  temp_file=$(mktemp "${file}.XXXXXX") || return 1
  printf '%s\n' "$theme" > "$temp_file"
  mv "$temp_file" "$file"
}

copy_file_atomically() {
  local source="$1"
  local target="$2"
  local temp_file

  [ -f "$source" ] || {
    echo "Missing theme asset: $source" >&2
    return 1
  }

  temp_file=$(mktemp "${target}.XXXXXX") || return 1
  if ! cp "$source" "$temp_file"; then
    unlink "$temp_file" 2>/dev/null || true
    return 1
  fi
  if ! mv "$temp_file" "$target"; then
    unlink "$temp_file" 2>/dev/null || true
    return 1
  fi
}

ensure_theme_link() {
  local source="$1"
  local target="$2"

  [ -e "$source" ] || {
    echo "Missing theme asset: $source" >&2
    return 1
  }

  if [ -L "$target" ]; then
    if [ "$source" -ef "$target" ]; then
      return 0
    fi
    echo "Refusing to replace a different theme asset: $target" >&2
    return 1
  fi

  if [ -e "$target" ]; then
    if [ -f "$source" ] && [ -f "$target" ] && cmp -s "$source" "$target"; then
      return 0
    fi
    echo "Refusing to replace a different theme asset: $target" >&2
    return 1
  fi

  ln -s "$source" "$target"
}

install_bat_theme() {
  local theme="$1"
  local source="$THEMES_DIR/codex/${theme}.tmTheme"
  local bat_config_dir
  local bat_cache_dir
  local target

  command -v bat >/dev/null 2>&1 || {
    echo "Skip bat/delta syntax theme: bat is not installed" >&2
    return 0
  }

  bat_config_dir=$(bat --config-dir) || return 1
  bat_cache_dir=$(bat --cache-dir) || return 1
  mkdir -p "$bat_config_dir/themes" || return 1
  target="$bat_config_dir/themes/${theme}.tmTheme"
  ensure_theme_link "$source" "$target" || return 1
  if [ ! -f "$bat_cache_dir/themes.bin" ] \
    || [ "$source" -nt "$bat_cache_dir/themes.bin" ] \
    || ! bat --list-themes | grep -Fqx "$theme"; then
    bat cache --build >/dev/null || return 1
  fi
  echo "Switch delta syntax theme assets to $theme"
}

apply_yazi_theme() {
  local theme="$1"
  local flavor="${2:-$theme}"
  local source_theme="$DOTFILES_DIR/yazi/theme.${theme}.toml"
  local source_flavor="$DOTFILES_DIR/yazi/${flavor}.yazi"
  local yazi_config_dir="${YAZI_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/yazi}"
  local target_flavor="$yazi_config_dir/flavors/${flavor}.yazi"

  mkdir -p "$yazi_config_dir/flavors" || return 1
  ensure_theme_link "$source_flavor" "$target_flavor" || return 1
  copy_file_atomically "$source_theme" "$yazi_config_dir/theme.toml" || return 1
  echo "Switch Yazi theme to $theme"
}

apply_codex_theme() {
  local theme="$1"
  local source="$THEMES_DIR/codex/${theme}.tmTheme"
  local codex_config_dir="${CODEX_HOME:-$HOME/.codex}"
  local target="$codex_config_dir/themes/${theme}.tmTheme"

  command -v python3 >/dev/null 2>&1 || {
    echo "Cannot switch Codex theme: python3 is not installed" >&2
    return 1
  }

  mkdir -p "$codex_config_dir/themes" || return 1
  ensure_theme_link "$source" "$target" || return 1
  python3 "$THEMES_DIR/update_theme_configs.py" codex \
    --file "$codex_config_dir/config.toml" --theme "$theme" || return 1
  echo "Switch Codex syntax theme to $theme (new or resumed sessions)"
}

# Usage: apply_pi_theme <pi theme name> <repo|npm package spec>
#
# Live switching: pi does not watch settings.json, but it does hot-reload the
# *active custom theme file* in ~/.pi/agent/themes/. So settings.json is pinned
# to theme "current" and every switch atomically replaces
# ~/.pi/agent/themes/current.json with a copy of the real theme; running
# sessions started with "current" repaint within ~100ms. Sources:
#   repo      -> themes/pi/<name>.json
#   npm:<pkg> -> ~/.pi/agent/npm/node_modules/<pkg>/themes/<name>.json
PI_LIVE_THEME="current"

apply_pi_theme() {
  local pi_theme="$1"
  local provider="$2"
  local pi_agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
  local settings_file="$pi_agent_dir/settings.json"
  local target="$pi_agent_dir/themes/${PI_LIVE_THEME}.json"
  local source pkg pkg_dir temp_file

  command -v python3 >/dev/null 2>&1 || {
    echo "Cannot switch pi theme: python3 is not installed" >&2
    return 1
  }

  [ -f "$settings_file" ] || {
    echo "Skip pi theme: settings file not found at $settings_file" >&2
    return 0
  }

  if [ "$provider" = "repo" ]; then
    source="$THEMES_DIR/pi/${pi_theme}.json"
  else
    pkg="${provider#npm:}"
    pkg_dir="$pi_agent_dir/npm/node_modules/$pkg"
    if ! grep -Fq "\"${provider}\"" "$settings_file" || [ ! -d "$pkg_dir" ]; then
      echo "Skip pi theme: install it first with: pi install ${provider}" >&2
      return 0
    fi
    source="$pkg_dir/themes/${pi_theme}.json"
    if [ ! -f "$source" ]; then
      # Package may declare a non-standard pi.themes dir; search it.
      source=$(find "$pkg_dir" -name "${pi_theme}.json" -not -path '*/node_modules/*/node_modules/*' 2>/dev/null | head -n 1)
    fi
  fi

  [ -n "$source" ] && [ -f "$source" ] || {
    echo "Missing pi theme: $pi_theme ($provider)" >&2
    return 1
  }
  mkdir -p "$pi_agent_dir/themes" || return 1
  # Copy with "name" rewritten to the live theme name: pi registers custom
  # themes by their JSON name, so this keeps /settings showing (and
  # re-selecting) "current" instead of silently persisting the real name and
  # unpinning settings.json.
  #
  # themes/pi/overrides/<name>.json, if present, is a partial theme whose
  # "vars"/"colors" keys are merged on top, so package themes can be tweaked
  # without forking them (upstream stays the source of truth).
  temp_file=$(mktemp "${target}.XXXXXX") || return 1
  python3 - "$source" "$temp_file" "$PI_LIVE_THEME" "$THEMES_DIR/pi/overrides/${pi_theme}.json" <<'EOF' || {
import json, os, sys
src, dst, live_name, override = sys.argv[1:5]
with open(src, encoding="utf-8") as f:
    data = json.load(f)
if not isinstance(data, dict) or "colors" not in data:
    sys.exit(f"not a pi theme: {src}")
if os.path.isfile(override):
    with open(override, encoding="utf-8") as f:
        patch = json.load(f)
    unknown = set(patch) - {"$schema", "vars", "colors", "export", "_comment"}
    if unknown:
        sys.exit(f"override {override}: unsupported top-level keys {sorted(unknown)}")
    for section in ("vars", "colors", "export"):
        if section in patch:
            data.setdefault(section, {}).update(patch[section])
    missing = [v for v in patch.get("colors", {}).values()
               if isinstance(v, str) and not v.startswith("#") and v and v not in data.get("vars", {})]
    if missing:
        sys.exit(f"override {override}: unknown var references {missing}")
# Theme schema has additionalProperties=false, so only "name" is rewritten.
data["name"] = live_name
with open(dst, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
EOF
    echo "Cannot prepare pi theme from $source" >&2
    unlink "$temp_file" 2>/dev/null || true
    return 1
  }
  mv "$temp_file" "$target" || {
    unlink "$temp_file" 2>/dev/null || true
    return 1
  }

  # Pin settings.json to the live theme once; later switches only touch the file.
  if ! grep -Eq "\"theme\"[[:space:]]*:[[:space:]]*\"${PI_LIVE_THEME}\"" "$settings_file"; then
    python3 "$THEMES_DIR/update_theme_configs.py" pi \
      --file "$settings_file" --theme "$PI_LIVE_THEME" || return 1
    echo "Pin pi settings.json theme to \"$PI_LIVE_THEME\" (sessions started before this need a restart once)"
  fi
  echo "Switch pi theme to $pi_theme (live via themes/${PI_LIVE_THEME}.json)"
}

apply_vscode_theme() {
  local theme_name="$1"
  local variant="${2:-}"
  local settings_file="${VSCODE_SETTINGS_FILE:-}"

  command -v python3 >/dev/null 2>&1 || {
    echo "Cannot switch VS Code theme: python3 is not installed" >&2
    return 1
  }

  if [ -z "$settings_file" ]; then
    case "$(uname -s)" in
      Darwin)
        settings_file="$HOME/Library/Application Support/Code/User/settings.json"
        ;;
      *)
        settings_file="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json"
        ;;
    esac
  fi

  [ -f "$settings_file" ] || {
    echo "Skip VS Code theme: settings file not found at $settings_file" >&2
    return 0
  }

  if [ -n "$variant" ]; then
    python3 "$THEMES_DIR/update_theme_configs.py" vscode \
      --file "$settings_file" --theme "$theme_name" --variant "$variant" || return 1
  else
    python3 "$THEMES_DIR/update_theme_configs.py" vscode \
      --file "$settings_file" --theme "$theme_name" || return 1
  fi
  echo "Switch VS Code theme to $theme_name"
}

# Herdr config.toml is generated: config.base.toml (keys/ui/terminal, the only
# file to edit by hand) + themes/<theme>.toml (colors only). Never edit
# config.toml directly; a theme switch would overwrite it.
apply_herdr_theme() {
  local theme="$1"
  local herdr_dir="$HOME/.config/herdr"
  local base="$herdr_dir/config.base.toml"
  local fragment="$herdr_dir/themes/${theme}.toml"
  local target="$herdr_dir/config.toml"
  local temp_file

  for f in "$base" "$fragment"; do
    [ -f "$f" ] || {
      echo "Missing Herdr config part: $f" >&2
      return 1
    }
  done

  temp_file=$(mktemp "${target}.XXXXXX") || return 1
  {
    printf '# GENERATED by theme_switcher.sh — do not edit.\n'
    printf '# Edit config.base.toml (settings) or themes/%s.toml (colors) instead.\n\n' "$theme"
    cat "$base"
    printf '\n'
    cat "$fragment"
  } > "$temp_file" || {
    unlink "$temp_file" 2>/dev/null || true
    return 1
  }

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$temp_file" 2>/dev/null || {
      echo "Generated Herdr config is not valid TOML; keeping the current one" >&2
      unlink "$temp_file" 2>/dev/null || true
      return 1
    }
  fi

  mv "$temp_file" "$target" || {
    unlink "$temp_file" 2>/dev/null || true
    return 1
  }

  echo "Switch Herdr theme to $theme"
  if command -v herdr >/dev/null 2>&1; then
    herdr server reload-config >/dev/null 2>&1 || true
  fi
}

# Ghostty: ghostty/config ends with `config-file = ?theme`, so we only rewrite
# that one-line include. Themes resolve from ~/.config/ghostty/themes first
# (converted from kitty via ghostty/kitty2ghostty-theme.sh), then built-ins.
# Live reload: Ghostty has no remote-control socket; on macOS use its
# AppleScript `perform action "reload_config"`, which reloads every surface.
apply_ghostty_theme() {
  local ghostty_theme="$1"
  local ghostty_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  local target="$ghostty_dir/theme"
  local temp_file

  [ -d "$ghostty_dir" ] || {
    echo "Skip Ghostty theme: $ghostty_dir not found" >&2
    return 0
  }
  if [ ! -e "$ghostty_dir/themes/$ghostty_theme" ] \
    && ! ghostty +list-themes --plain 2>/dev/null | grep -Fqx "$ghostty_theme (resources)"; then
    echo "Missing Ghostty theme: $ghostty_theme" >&2
    return 1
  fi

  temp_file=$(mktemp "${target}.XXXXXX") || return 1
  cat > "$temp_file" <<EOF || { unlink "$temp_file" 2>/dev/null; return 1; }
# GENERATED by theme_switcher.sh (sth set <theme>) — do not edit by hand.
# Custom themes: ls ~/.config/ghostty/themes   Built-in: ghostty +list-themes
theme = $ghostty_theme
EOF
  mv "$temp_file" "$target" || {
    unlink "$temp_file" 2>/dev/null || true
    return 1
  }
  echo "Switch Ghostty theme to $ghostty_theme"

  # Reload running Ghostty (macOS only). Skip silently if it isn't running so
  # osascript doesn't launch it.
  if [ "$(uname -s)" = "Darwin" ] && pgrep -xq ghostty; then
    osascript -e 'tell application "Ghostty" to perform action "reload_config" on focused terminal of selected tab of front window' >/dev/null 2>&1 \
      || echo "Ghostty is running but reload failed; press cmd+shift+, to reload" >&2
  fi
}

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

  if ! is_valid_theme "$theme"; then
    echo "Unknown theme: $theme" >&2
    list_themes >&2
    return 1
  fi

  # Install custom syntax assets before changing any active application files.
  case "$theme" in
    "kanagawa-lotus"|"rose-pine-dawn"|"rose-pine-moon"|"everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      install_bat_theme "$theme" || return 1
      ;;
  esac
  
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
      "kanagawa-lotus")
        tmux source-file "$HOME/.config/themes/tmux/kanagawa-lotus.tmux" || return 1
        ;;
      "rose-pine-dawn"|"rose-pine-moon")
        tmux source-file "$HOME/.config/themes/tmux/${theme}.tmux" || return 1
        ;;
      "tokyoday")
        tmux source-file "$HOME/.config/themes/tmux/tokyoday.tmux"
        ;;
      "tokyonight")
        tmux source-file "$HOME/.config/themes/tmux/tokyonight.tmux"
        ;;
      "everforest")
        tmux source-file "$HOME/.config/themes/tmux/everforest.tmux"
        ;;
      "everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
        tmux source-file "$HOME/.config/themes/tmux/${theme}.tmux" || return 1
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
    "kanagawa-lotus")
      echo "Switch fzf theme to kanagawa lotus"
      copy_file_atomically "$HOME/.config/themes/fzf/kanagawa-lotus.sh" \
        "$HOME/.config/themes/current_fzf_theme" || return 1
      source "$HOME/.config/themes/fzf/kanagawa-lotus.sh"
      ;;
    "rose-pine-dawn"|"rose-pine-moon")
      echo "Switch fzf theme to $theme"
      copy_file_atomically "$HOME/.config/themes/fzf/${theme}.sh" \
        "$HOME/.config/themes/current_fzf_theme" || return 1
      source "$HOME/.config/themes/fzf/${theme}.sh"
      ;;
    "tokyoday")
      echo "Switch fzf theme to tokyoday"
      # Write to a file that will be sourced by .zshrc
      cat "$HOME/.config/themes/fzf/tokyoday.sh" > "$HOME/.config/themes/current_fzf_theme"
      # Also apply to current shell
      source "$HOME/.config/themes/fzf/tokyoday.sh"
      ;;
    "tokyonight")
      echo "Switch fzf theme to tokyonight"
      # Write to a file that will be sourced by .zshrc
      cat "$HOME/.config/themes/fzf/tokyonight.sh" > "$HOME/.config/themes/current_fzf_theme"
      # Also apply to current shell
      source "$HOME/.config/themes/fzf/tokyonight.sh"
      ;;
    "everforest")
      echo "Switch fzf theme to everforest"
      # Write to a file that will be sourced by .zshrc
      cat "$HOME/.config/themes/fzf/everforest.sh" > "$HOME/.config/themes/current_fzf_theme"
      # Also apply to current shell
      source "$HOME/.config/themes/fzf/everforest.sh"
      ;;
    "everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      echo "Switch fzf theme to $theme"
      copy_file_atomically "$HOME/.config/themes/fzf/${theme}.sh" \
        "$HOME/.config/themes/current_fzf_theme" || return 1
      source "$HOME/.config/themes/fzf/${theme}.sh" || return 1
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
    "kanagawa-lotus")
      echo "Switch lazygit theme to kanagawa lotus"
      copy_file_atomically "$HOME/.config/lazygit/config.kanagawa-lotus.yml" \
        "$HOME/.config/lazygit/config.yml" || return 1
      ;;
    "rose-pine-dawn"|"rose-pine-moon")
      echo "Switch lazygit theme to $theme"
      copy_file_atomically "$HOME/.config/lazygit/config.${theme}.yml" \
        "$HOME/.config/lazygit/config.yml" || return 1
      ;;
    "tokyoday")
      echo "Switch lazygit theme to tokyoday"
      cp "$HOME/.config/lazygit/config.tokyoday.yml" "$HOME/.config/lazygit/config.yml"
      ;;
    "tokyonight")
      echo "Switch lazygit theme to tokyonight"
      cp "$HOME/.config/lazygit/config.tokyonight.yml" "$HOME/.config/lazygit/config.yml"
      ;;
    "everforest")
      echo "Switch lazygit theme to everforest"
      cp "$HOME/.config/lazygit/config.everforest.yml" "$HOME/.config/lazygit/config.yml"
      ;;
    "everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      echo "Switch lazygit theme to $theme"
      copy_file_atomically "$HOME/.config/lazygit/config.${theme}.yml" \
        "$HOME/.config/lazygit/config.yml" || return 1
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
    "kanagawa-lotus")
      echo "Switch kitty theme to kanagawa lotus"
      copy_file_atomically "$HOME/.config/kitty/themes/kanagawa-lotus.conf" \
        "$HOME/.config/kitty/current_theme.conf" || return 1
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/kanagawa-lotus.conf" 2>/dev/null
      ;;
    "rose-pine-dawn"|"rose-pine-moon")
      echo "Switch kitty theme to $theme"
      copy_file_atomically "$HOME/.config/kitty/themes/${theme}.conf" \
        "$HOME/.config/kitty/current_theme.conf" || return 1
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/${theme}.conf" 2>/dev/null
      ;;
    "tokyoday")
      echo "Switch kitty theme to tokyoday"
      cp "$HOME/.config/kitty/themes/tokyo-night-day.conf" "$HOME/.config/kitty/current_theme.conf"
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/tokyo-night-day.conf" 2>/dev/null
      ;;
    "tokyonight")
      echo "Switch kitty theme to tokyonight"
      cp "$HOME/.config/kitty/themes/tokyo-night.conf" "$HOME/.config/kitty/current_theme.conf"
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/tokyo-night.conf" 2>/dev/null
      ;;
    "everforest")
      echo "Switch kitty theme to everforest"
      cp "$HOME/.config/kitty/themes/everforest-dark-medium.conf" "$HOME/.config/kitty/current_theme.conf"
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/everforest-dark-medium.conf" 2>/dev/null
      ;;
    "everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      echo "Switch kitty theme to $theme"
      copy_file_atomically "$HOME/.config/kitty/themes/${theme}.conf" \
        "$HOME/.config/kitty/current_theme.conf" || return 1
      kitty @ set-colors --all --configured "$HOME/.config/kitty/themes/${theme}.conf" 2>/dev/null
      ;;
    *)
      echo "No specific kitty theme for $theme"
      ;;
  esac

  # Apply to Ghostty. Names match ~/.config/ghostty/themes (mirrors the kitty map).
  case "$theme" in
    "gruvbox")        apply_ghostty_theme "gruvbox-dark-soft" || return 1 ;;
    "quietlight")     apply_ghostty_theme "quiet-light" || return 1 ;;
    "kanagawa-lotus") apply_ghostty_theme "kanagawa-lotus" || return 1 ;;
    "rose-pine-dawn"|"rose-pine-moon") apply_ghostty_theme "$theme" || return 1 ;;
    "tokyoday")       apply_ghostty_theme "tokyo-night-day" || return 1 ;;
    "tokyonight")     apply_ghostty_theme "tokyo-night" || return 1 ;;
    "everforest")     apply_ghostty_theme "everforest-dark-medium" || return 1 ;;
    "everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      apply_ghostty_theme "$theme" || return 1 ;;
    # Ghostty built-ins (ghostty +list-themes); no local conversion needed.
    "catppuccin-frappe") apply_ghostty_theme "Catppuccin Frappe" || return 1 ;;
    "nordfox")           apply_ghostty_theme "Nordfox" || return 1 ;;
    *) echo "No specific Ghostty theme for $theme" ;;
  esac

  # Apply to Herdr (config.base.toml + themes/<theme>.toml -> config.toml).
  case "$theme" in
    "quietlight"|"kanagawa-lotus"|"rose-pine-dawn"|"rose-pine-moon"|"tokyonight"|"everforest"|"everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      apply_herdr_theme "$theme" || return 1
      ;;
    "catppuccin-frappe"|"nordfox")
      apply_herdr_theme "$theme" || return 1
      ;;
  esac

  # Apply to pi. Repo-owned themes live in themes/pi; the rest are pi packages.
  case "$theme" in
    "quietlight"|"kanagawa-lotus"|"gruvbox"|"rose-pine-moon")
      apply_pi_theme "$theme" repo || return 1
      ;;
    "solarized-dark"|"tokyonight")
      apply_pi_theme "$theme" "npm:@inobit/pi-themes" || return 1
      ;;
    "rose-pine-dawn")
      apply_pi_theme "rosepine-dawn" "npm:@inobit/pi-themes" || return 1
      ;;
    "tokyoday")
      apply_pi_theme "tokyonight-day" "npm:@inobit/pi-themes" || return 1
      ;;
    "everforest")
      apply_pi_theme "everforest-dark-medium" "npm:pi-everforest" || return 1
      ;;
    "everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      apply_pi_theme "$theme" "npm:pi-everforest" || return 1
      ;;
  esac

  case "$theme" in
    "quietlight")
      apply_yazi_theme "$theme" "vscode-quiet-light" || return 1
      apply_codex_theme "$theme" || return 1
      apply_vscode_theme "Quiet Light" || return 1
      ;;
    "kanagawa-lotus")
      apply_yazi_theme "$theme" || return 1
      apply_codex_theme "$theme" || return 1
      apply_vscode_theme "Kanagawa Lotus" || return 1
      ;;
    "rose-pine-dawn")
      apply_yazi_theme "$theme" || return 1
      apply_codex_theme "$theme" || return 1
      apply_vscode_theme "Rosé Pine Dawn" || return 1
      ;;
    "rose-pine-moon")
      apply_yazi_theme "$theme" || return 1
      apply_codex_theme "$theme" || return 1
      apply_vscode_theme "Rosé Pine Moon" || return 1
      ;;
    "everforest-light-hard"|"everforest-light-medium"|"everforest-light-soft")
      local everforest_variant="${theme##*-}"
      apply_yazi_theme "$theme" || return 1
      apply_codex_theme "$theme" || return 1
      apply_vscode_theme "Everforest Light" "$everforest_variant" || return 1
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
      "kanagawa-lotus")
        printf '\033]1337;SetColors=preset=Kanagawa Lotus\a' > /dev/tty
        ;;
      "rose-pine-dawn")
        # iTerm2 normalizes imported preset filenames to NFD (e + U+0301).
        printf '\033]1337;SetColors=preset=Rose\314\201 Pine Dawn\a' > /dev/tty
        ;;
      "rose-pine-moon")
        printf '\033]1337;SetColors=preset=Rose\314\201 Pine Moon\a' > /dev/tty
        ;;
      "everforest-light-hard")
        printf '\033]1337;SetColors=preset=Everforest Light Hard\a' > /dev/tty
        ;;
      "everforest-light-medium")
        printf '\033]1337;SetColors=preset=Everforest Light Medium\a' > /dev/tty
        ;;
      "everforest-light-soft")
        printf '\033]1337;SetColors=preset=Everforest Light Soft\a' > /dev/tty
        ;;
    esac
  fi

  # Publish the state only after all required integrations have succeeded.
  # Neovim watches its state file and applies the new colors to running instances.
  write_theme_file "$HOME/.config/nvim/current_theme" "$theme" || return 1
  write_theme_file "$THEME_FILE" "$theme" || return 1
  
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
