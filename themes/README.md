# Unified terminal themes

Symlink this directory to `~/.config/themes`, then use:

```sh
sth list
sth set kanagawa-lotus
sth set rose-pine-dawn
sth set everforest-light-hard
sth set everforest-light-medium
sth set everforest-light-soft
```

The complete light-theme profiles cover:

- Kitty, tmux, fzf, Neovim, Lazygit, and its delta pager
- Herdr full configuration templates
- Yazi flavors
- Codex CLI syntax and diff highlighting
- pi coding agent TUI themes
- VS Code's active user settings
- iTerm2 presets when the matching `.itermcolors` files are imported

The switcher installs repository-owned Yazi, bat, and Codex theme assets as
non-destructive symlinks. It refuses to replace a different existing asset.
VS Code needs the extensions listed in `vscode/extensions.txt`. Codex applies a
new syntax theme to new or resumed sessions; the terminal background still
comes from Kitty or iTerm2.

## pi

The switcher sets `theme` in `~/.pi/agent/settings.json`; running pi sessions
keep their theme, new ones pick up the change. Themes come from two places:

- Repository-owned JSON in `pi/`, symlinked into `~/.pi/agent/themes/`:
  `quietlight`, `kanagawa-lotus`, `gruvbox` (dark soft). These follow the
  palettes already used by the Kitty and Codex assets in this repository.
- Open-source pi packages, installed once with `pi install`:

  ```sh
  pi install npm:@inobit/pi-themes   # solarized-dark, rosepine-dawn, tokyonight, tokyonight-day
  pi install npm:pi-everforest       # everforest-dark-medium, everforest-light-{hard,medium,soft}
  ```

  If a package is missing, the switcher prints the install command and leaves
  the pi theme untouched.

| `sth` theme | pi theme | source |
|-------------|----------|--------|
| `solarized-dark` | `solarized-dark` | `@inobit/pi-themes` |
| `quietlight` | `quietlight` | `pi/quietlight.json` |
| `kanagawa-lotus` | `kanagawa-lotus` | `pi/kanagawa-lotus.json` |
| `rose-pine-dawn` | `rosepine-dawn` | `@inobit/pi-themes` |
| `gruvbox` | `gruvbox` | `pi/gruvbox.json` |
| `tokyoday` | `tokyonight-day` | `@inobit/pi-themes` |
| `tokyonight` | `tokyonight` | `@inobit/pi-themes` |
| `everforest` | `everforest-dark-medium` | `pi-everforest` |
| `everforest-light-*` | same name | `pi-everforest` |

Upstream sources:

- Kanagawa.nvim `bb85e4b` for the Lotus palette, Neovim plugin, and Kitty base
- Rosé Pine Neovim `ff483051`, Kitty `efd4f01c`, TextMate `6d556734`, and iTerm `4801702a`
- Yazi's indexed Kanagawa Lotus `adc1be6a` and Rosé Pine Dawn `d82f54f7` flavors
- `mbadolato/iTerm2-Color-Schemes` for the Kanagawa Lotus iTerm2 preset
- VS Code extensions `metaphore.kanagawa-vscode-color-theme` and `mvllow.rose-pine`
- Everforest `85a86eb6` hard, medium, and soft light palettes; TUI-only semantic
  accents are darkened where the upstream terminal colors are too faint for labels
- VS Code extension `sainnhe.everforest`; its upstream is archived but still
  exposes the required `everforest.lightContrast` hard/medium/soft setting
