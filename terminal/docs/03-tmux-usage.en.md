# tmux Daily Workflow & Common Commands

> 中文:[03-tmux-usage.zh.md](./03-tmux-usage.zh.md)
> Prefix is the default `Ctrl+b`; below, `prefix + x` = press `Ctrl+b`, release, then `x`.

## Mental model: one session per project

```bash
tmux new -s saas        # create & enter a session for project "saas"
# open a few windows for sub-tasks (below)
tmux new -s bike        # another project, another set
```

Recommended window layout per project:

```
session: saas
  ├─ window 0: claude   main Claude Code session
  ├─ window 1: dev      dev server (pnpm dev) so agents can read its logs
  └─ window 2: git      diffs / commits
```

## Most-used commands

### Session
| Action | Command |
|--------|---------|
| New & named | `tmux new -s name` |
| List all | `tmux ls` |
| Reattach | `tmux attach -t name` |
| Detach (keep running) | `prefix + d` |
| Kill | `tmux kill-session -t name` |

### Window (tab)
| Action | Key |
|--------|-----|
| New (keeps cwd) | `prefix + c` |
| Next / prev | `prefix + n` / `prefix + p` |
| Jump to Nth | `prefix + number` |
| Pick from list | `prefix + w` |
| Rename | `prefix + ,` |
| Close | `prefix + &` |

> **Window naming (tuned in this config)**: by default tmux renames windows to the
> running program (everything shows "bash" — useless). This config instead:
> **unnamed windows show their directory** (e.g. `saas`), and a **manual name via
> `prefix + ,` sticks** (e.g. `claude`/`dev`/`git`); programs can't silently rename
> them. A `•` appears in the status bar when a background window has new output —
> handy for spotting "which agent just finished". **Name each window by role** so the
> status bar tells you what every window is doing at a glance. To peek at all windows,
> `prefix + w` opens a window tree with live preview.

### Pane (split)
| Action | Key |
|--------|-----|
| Vertical split (keeps cwd) | `prefix + |` |
| Horizontal split (keeps cwd) | `prefix + -` |
| Switch panes | `prefix + h/j/k/l` (arrows also work) |
| Resize | `prefix + hold arrow` or mouse drag |
| Zoom / unzoom current pane | `prefix + z` |
| Close | `prefix + x` or `exit` |

### Copy / scroll history (vi keys)
- Enter copy mode: `prefix + [`
- Page `Ctrl-u`/`Ctrl-d`, line `j`/`k`, search `/`, select `v`, copy `y`, quit `q`
- Mouse works too: wheel to scroll, drag to select

### Opening URLs (Ghostty + tmux)
- **`Cmd + Shift + click`** a link to open it in your browser.
- Why the `Shift`: with `mouse on`, tmux captures clicks. Holding `Shift`
  bypasses tmux's mouse grab (Ghostty's `mouse-shift-capture` default) so Ghostty
  handles the click; `Cmd` is Ghostty's open-link modifier on macOS. Hold `Cmd`
  while hovering to see the link underline first.
- Outside tmux (plain Ghostty), `Cmd + click` alone works — the extra `Shift` is
  only needed because tmux is grabbing the mouse.

### Misc
- Reload config: `prefix + r` (custom in this config)
- Manual save: `prefix + Ctrl-s`; restore: `prefix + Ctrl-r`

## Persistence: restore across restarts

This config installs **tmux-resurrect + tmux-continuum**:
- continuum auto-saves every ~15 min and **auto-restores on tmux start** — the last
  session/window/pane layout and **each pane's cwd**.
- resurrect does the actual save/restore (with `@resurrect-capture-pane-contents on`,
  pane contents are saved too).

First run: inside tmux press `prefix + I` (capital) to install plugins. After that
it's basically invisible — reboot, kill tmux, run `tmux` again and you're back.

> This is the thorough fix for the original Ghostty lost-cwd pain: the session lives
> in a background process, so directories and running processes never die; even after
> a reboot, continuum pulls the layout and directories back.

## Tips for pairing with Claude Code
- Put the dev server in its own window; an agent can read it via
  `tmux capture-pane -t dev -p` to judge state.
- Claude Code understands tmux: you can have it read a pane or send keys to a pane.
- Shift+Enter newline is wired through `extended-keys` + the Ghostty keybind.
