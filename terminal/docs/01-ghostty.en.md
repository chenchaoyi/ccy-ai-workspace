# Ghostty Config — Notes & Tuning

> 中文:[01-ghostty.zh.md](./01-ghostty.zh.md)

## What this config does

Replicates Warp "phenomenon" dark feel (Hack 15pt, near-black bg, warm off-white
fg, periwinkle cursor). Adds agent-friendly settings: bell attention, jump between
prompts, large scrollback.

## Contrast / "glare" finding ⭐

**Symptom**: the original config used pure-white fg `#fffefb` on near-black
`#111111`; text felt glaring and tiring to read.

**Cause**: three stacking factors.

| Setting | Old | Problem |
|---------|-----|---------|
| `foreground` | `#fffefb` near-white | ~17:1 contrast (WCAG AAA needs only 7:1) → bright pixels "halate" |
| `background` | `#111111` near-black | darker bg makes white edges bloom more |
| `font-thicken` | `true` | faux-bold stroke makes white text heavier/harsher |

**Tuning applied**:

| Setting | New | Effect |
|---------|-----|--------|
| `foreground` | `#d4d2cc` warm off-white | contrast down to ~10:1, readable but not harsh |
| `background` | `#17171a` | bg raised a notch with a cool tint, less bloom |
| `font-thicken` | `false` | normal stroke weight |

**Further tweaks**: too bright → lower fg to `c8c6c0`/`bdbbb5`; too gray → back to `e0ded8`.

## "Working directory lost after quit" finding

**Symptom**: after `Cmd+Q` and relaunch, window positions return but each
tab/split's cwd resets to home.

**Root cause**: on macOS `window-save-state = always` only guarantees **window
geometry**. Restoring **each surface's cwd** is "rich state" that depends on:
(1) shell integration reporting cwd (enabled via `shell-integration = detect`);
(2) macOS native state restoration, gated by **System Settings → Desktop & Dock →
"Close windows when quitting an application"**. That box is on by default → rich
state is dropped on quit → only geometry comes back.

**Two ways out** (see `04` and below):
1. **Enable native restore**: `defaults write -g NSQuitAlwaysKeepsWindows -bool true`
   (or uncheck that box). Global, best-effort.
2. **Switch to tmux** (this repo's choice): the session lives in a background
   process, so cwd/layout/running processes survive. With resurrect/continuum it
   survives reboots. More thorough than native restore.

> Snapshot tools also evaluated: **gtab** (named workspaces),
> **crex/cmux-resurrect** (auto-snapshot daemon, restores running processes),
> **ghostty-workspace** (declarative YAML). For heavy use, go tmux; see `04`.

## Config load-path gotcha

Ghostty loads a file literally named `config` (no extension) from:
- `~/.config/ghostty/config` (XDG, cross-platform preferred)
- `~/Library/Application Support/com.mitchellh.ghostty/config` (macOS)

This machine historically had the live config named `config.ghostty` (non-standard
name, but loaded). On migration, `install.sh` copies to the standard
`~/.config/ghostty/config` and backs up the old `config.ghostty` to avoid
double-loading. Verify the effective config:
`/Applications/Ghostty.app/Contents/MacOS/ghostty +show-config | grep foreground`.
