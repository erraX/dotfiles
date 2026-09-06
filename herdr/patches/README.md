# Local Herdr patches

## `selection-contrast-v0.8.2.patch`

- Base: Herdr `v0.8.2`, commit `9eb521456ac0d19d3ab3d9d7cea3cca10baa8a4c`
- Original binary SHA-256: `a5d4f4d504d8b309c91f811050559300faba31258425f53c50852fc96f6ae574`
- Patched binary SHA-256: `5008c14f8bdfb03f4a90b303ebc80594fe0a2925afd70e4c80fd658ffa3756d2`
- Backup: `~/.local/bin/herdr.v0.8.2-original-a5d4f4d5`

Apply the stored zero-context patch with:

```sh
git apply --unidiff-zero selection-contrast-v0.8.2.patch
```

Herdr 0.8.2 derives a mid-tone pane-selection background from the host
terminal, then chooses named ANSI black or white with a `0.5` luminance
threshold. Light terminal palettes can therefore render low-contrast text
because both the threshold and the terminal's ANSI remapping work against the
intended contrast.

The patch compares actual black and white contrast ratios and emits truecolor
RGB black or white, so terminal ANSI palettes cannot remap the chosen
foreground. It includes light and dark host-background regression coverage.

Verified on macOS arm64 with `just lint`, all 75 selection tests, the full
3,327-test Rust suite, 98 maintenance tests, 6 UI architecture tests, and 26
integration-asset tests before the release binary was installed by live handoff.

Remove this patch and its local binary when an installed upstream Herdr release
contains an equivalent fix.

`herdr update` replaces `~/.local/bin/herdr`. After an update, check whether the
upstream release contains the fix before reapplying this patch.
