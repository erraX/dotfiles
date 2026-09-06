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
- VS Code's active user settings
- iTerm2 presets when the matching `.itermcolors` files are imported

The switcher installs repository-owned Yazi, bat, and Codex theme assets as
non-destructive symlinks. It refuses to replace a different existing asset.
VS Code needs the extensions listed in `vscode/extensions.txt`. Codex applies a
new syntax theme to new or resumed sessions; the terminal background still
comes from Kitty or iTerm2.

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
