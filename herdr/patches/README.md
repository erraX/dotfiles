# Local Herdr patches

All patches target Herdr `v0.8.2` (tag → commit
`4c979bfd86096c6cf699d9921428011a38c25b31`, upstream
https://github.com/motionharvest/herdr).

- Original release binary SHA-256: `a5d4f4d504d8b309c91f811050559300faba31258425f53c50852fc96f6ae574`
  (backup: `~/.local/bin/herdr.v0.8.2-original-a5d4f4d5`)
- Selection-contrast-only build SHA-256: `5008c14f8bdfb03f4a90b303ebc80594fe0a2925afd70e4c80fd658ffa3756d2`
  (backup: `~/.local/bin/herdr.v0.8.2-selection-only-5008c14f`)
- Current installed build (both patches, ad-hoc signed) SHA-256:
  `f1eada4ee86414daf742d978eecbf61c62c038e44aec77a60c09497f3e20acce`

## Rebuild

```sh
git clone --depth 1 --branch v0.8.2 https://github.com/motionharvest/herdr /tmp/herdr-src
cd /tmp/herdr-src
git apply ~/workspace/github/dotfiles/herdr/patches/*.patch
cargo test --release      # 1 pre-existing failure on macOS: sidebar /var vs /private/var
cargo build --release
trash ~/.local/bin/herdr && cp target/release/herdr ~/.local/bin/herdr
codesign -s - -f ~/.local/bin/herdr   # in-place cp over a signed binary gets SIGKILLed
herdr server stop && herdr             # running server keeps the old binary until restarted
```

`herdr update` replaces `~/.local/bin/herdr`. After an update, check whether the
upstream release contains equivalent fixes before reapplying.

## `copy-mode-key-repeat-v0.8.2.patch`

Herdr only replays enhanced-keyboard `Repeat` events (Ghostty/kitty protocol
"report event types") while in **Terminal** mode. In copy mode every repeat is
dropped, so holding `ctrl+d` / `ctrl+u` / `j` / `k` scrolls exactly once.

The patch tracks which mode saw the original `Press` and additionally replays
repeats in **Copy** mode for keys that were pressed inside copy mode. Guards
kept:

- Keys pressed in Prefix/modal modes (e.g. the `space` of `prefix+space`) still
  never repeat inside copy mode.
- Copy-mode exit keys (`q`, `Esc`, `y`) still don't leak repeats into the shell.

Files: `src/app/mod.rs`, `src/app/runtime.rs`, tests in
`src/app/input/copy_mode.rs`. Worth upstreaming.

## `selection-contrast-v0.8.2.patch`

Herdr derives a mid-tone pane-selection background from the host terminal,
then chooses named ANSI black or white with a `0.5` luminance threshold. Light
terminal palettes can render low-contrast text because both the threshold and
the terminal's ANSI remapping work against the intended contrast.

The patch compares actual black and white contrast ratios and emits truecolor
RGB black or white, so terminal ANSI palettes cannot remap the chosen
foreground. Includes light and dark host-background regression coverage.

Re-ported 2026-09-11: the original patch was written against a commit
(`9eb52145`) that no longer exists upstream; the `v0.8.2` tag now points at
`4c979bfd`, which already exposes `contrast_ratio(Rgb, Rgb)`, so the patch now
reuses that helper.
