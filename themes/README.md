# Unified terminal themes

Symlink this directory to `~/.config/themes`, then use:

```sh
sth list
sth set kanagawa-lotus
sth set rose-pine-dawn
sth set rose-pine-moon
sth set everforest-light-hard
sth set everforest-light-medium
sth set everforest-light-soft
```

The complete theme profiles (the light ones plus Rosé Pine Moon) cover:

- Kitty, Ghostty, tmux, fzf, Neovim, Lazygit, and its delta pager
- Herdr (generated `config.toml`, see below)
- Yazi flavors
- Codex CLI syntax and diff highlighting
- pi coding agent TUI themes
- VS Code's active user settings
- iTerm2 presets when the matching `.itermcolors` files are imported

## Partial dark profiles (Ghostty, Herdr, Neovim only)

`kanagawa-dragon`, `catppuccin-frappe`, `terafox`, `nordfox` and
`gruvbox-material` (dark medium) currently switch only Ghostty, Herdr and
Neovim; kitty, tmux, fzf, Lazygit, Yazi, Codex, pi and VS Code keep whatever
was active before. Ghostty uses its built-in themes, Neovim the upstream
plugins (`catppuccin/nvim`, `EdenEast/nightfox.nvim`,
`sainnhe/gruvbox-material`, `rebelot/kanagawa.nvim`), and the Herdr
`[theme.custom]` fragments copy the palettes straight from those plugins'
palette sources since Herdr ships no matching built-ins.

The switcher installs repository-owned Yazi, bat, and Codex theme assets as
non-destructive symlinks. It refuses to replace a different existing asset.
VS Code needs the extensions listed in `vscode/extensions.txt`. Codex applies a
new syntax theme to new or resumed sessions; the terminal background still
comes from Kitty or iTerm2.

## Herdr

`~/.config/herdr/config.toml` is **generated** on every `sth set`:

```
herdr/config.base.toml      keys, ui, terminal, toast… — edit this one
+ herdr/themes/<theme>.toml  [ui.sidebar.agents] rows, [theme], [theme.custom]
= herdr/config.toml          do not edit; a theme switch overwrites it
```

So prefix/keybinding changes go in `config.base.toml` only and survive every
theme switch. The switcher validates the concatenation with `tomllib` before
replacing the file, then runs `herdr server reload-config`.

## Ghostty

`ghostty/config` ends with `config-file = ?theme`; the switcher rewrites that
one-line `ghostty/theme` include and reloads a running Ghostty via its
AppleScript `perform action "reload_config"` (macOS). Theme names mirror the
kitty map (`everforest` → `everforest-dark-medium`, `quietlight` →
`quiet-light`, …) and resolve from `ghostty/themes/` first, then Ghostty's
built-ins. Regenerate the custom themes from kitty with
`ghostty/kitty2ghostty-theme.sh`. `solarized-dark` is unmapped, same as kitty.

## pi

Switching is **live**: running pi sessions repaint within ~100ms. pi does not
watch `settings.json`, but it does hot-reload the active custom theme file, so
the switcher pins `settings.json` to `"theme": "current"` (once) and on every
switch atomically replaces `~/.pi/agent/themes/current.json` with a copy of the
real theme, with its JSON `name` rewritten to `current` so pi registers and
pre-selects it under that name in `/settings`. Consequences: `/settings` shows
`current` (re-selecting it is harmless; picking any other theme there unpins
`settings.json` until the next `sth set`), sessions started before the pin was
applied need one restart, and after upgrading a theme package run `sth set`
again to refresh the copy.

Themes come from two places:

- Repository-owned JSON in `pi/`: `quietlight`, `kanagawa-lotus`, `gruvbox`
  (dark soft), `rose-pine-moon`. These follow the palettes already used by the Kitty and Codex
  assets in this repository.
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
| `rose-pine-moon` | `rose-pine-moon` | `pi/rose-pine-moon.json` (`@inobit/pi-themes` only ships main + dawn) |
| `gruvbox` | `gruvbox` | `pi/gruvbox.json` |
| `tokyoday` | `tokyonight-day` | `@inobit/pi-themes` |
| `tokyonight` | `tokyonight` | `@inobit/pi-themes` |
| `everforest` | `everforest-dark-medium` | `pi-everforest` |
| `everforest-light-*` | same name | `pi-everforest` |

Upstream sources:

- Kanagawa.nvim `bb85e4b` for the Lotus palette, Neovim plugin, and Kitty base
- Rosé Pine Neovim `ff483051`, Kitty `efd4f01c`, TextMate `6d556734`, and iTerm `4801702a`
- Rosé Pine Moon: upstream `rose-pine/kitty`, `rose-pine/tm-theme` and `rose-pine/iterm`
  dist files as of 2026-09; Herdr and pi palettes hand-mapped from the official Moon
  variables since neither ships a Moon variant
- Yazi's indexed Kanagawa Lotus `adc1be6a` and Rosé Pine Dawn `d82f54f7` flavors;
  Rosé Pine Moon from `Mintass/rose-pine-moon.yazi` with the same inactive-tab
  contrast fix as Dawn
- `mbadolato/iTerm2-Color-Schemes` for the Kanagawa Lotus iTerm2 preset
- VS Code extensions `metaphore.kanagawa-vscode-color-theme` and `mvllow.rose-pine`
- Everforest `85a86eb6` hard, medium, and soft light palettes; TUI-only semantic
  accents are darkened where the upstream terminal colors are too faint for labels
- VS Code extension `sainnhe.everforest`; its upstream is archived but still
  exposes the required `everforest.lightContrast` hard/medium/soft setting
