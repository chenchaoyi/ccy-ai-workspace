# Terminal Workspace (Ghostty + tmux + Coding Agents)

> 🌏 **中文版见 [README.zh.md](./README.zh.md)** · English version below.

My local terminal environment — **config + usage + decision log** — kept under
version control so I can:
- **restore on a new machine in one command**;
- **share** the setup with teammates.

## Layout

```
terminal/
├── README.md            ← you are here: overview + one-command restore
├── README.zh.md         中文版
├── install.sh           symlink configs into place + install tpm
├── ghostty/
│   └── config           Ghostty config (soft dark / agent-friendly)
├── tmux/
│   └── tmux.conf        tmux config (keeps default Ctrl+b prefix)
├── scripts/
│   └── tmux-restore     restore the Ghostty ↔ tmux workspace (reattach all sessions)
├── shell/
│   └── ghostty-cwd.bash cwd reporting for macOS bash 3.2 (new windows inherit cwd)
└── docs/
    ├── 01-ghostty.en.md       Ghostty config + contrast/glare tuning + cwd-restore findings
    ├── 02-tmux-concepts.en.md tmux concepts: server / session / window / pane
    ├── 03-tmux-usage.en.md     daily workflow: one session per project, window layout, persistence
    ├── 04-agents-tmux.en.md    Coding agents + tmux best-practice digest
    ├── 05-workflows.en.md      3 worked scenarios + screen layout + browsing code in terminal
    └── *.zh.md                 Chinese version of each doc
```

## One-command restore (new machine)

```bash
# Prereq: Ghostty (>= 1.3) and tmux (>= 3.3) installed
#   brew install --cask ghostty ; brew install tmux
git clone git@github.com:chenchaoyi/ccy-ai-workspace.git
cd ccy-ai-workspace
bash terminal/install.sh
```

The installer checks both tools' presence and versions up front (and offers a
`brew upgrade` — after asking — when a newer one is available).

The script **copies** configs to:
- `~/.config/ghostty/config`
- `~/.tmux.conf`
- `~/.local/bin/tmux-restore` (CLI, callable from any directory — see below;
  deliberately NOT wired into any shell rc file, works regardless of your shell)
- `~/.ghostty-cwd.bash` (only needed by bash users — see "Working-directory
  inheritance" below)

and clones tpm. Existing files are auto-backed-up as `*.bak.<timestamp>`.

> Copy, not symlink: configs change rarely, so a plain copy keeps things simple and
> avoids surprises. After editing files in the repo, **re-run `bash terminal/install.sh`**
> to apply them.

## After install

1. **Ghostty**: reopen, or press `Cmd+Shift+,` to reload.
2. **tmux**: run `tmux` → press `Ctrl+b` then `I` (capital) to install plugins.
3. **Verify persistence**: `Ctrl+b` then `Ctrl-s` to save once; restart tmux and
   the layout + each pane's cwd should auto-restore.

## Reattaching tmux sessions (`tmux-restore`)

Quitting Ghostty leaves the tmux server and all sessions alive — only the
Ghostty tabs are gone. After reopening Ghostty, run **once** in any tab:

```bash
tmux-restore             # one tab per tmux session, all attached
```

It opens one Ghostty tab per session (via Ghostty 1.3+'s native AppleScript
support) and attaches them all; the tab you ran it in takes the first session.
Leftover blank tabs restored by `window-save-state` can just be closed (Cmd+W).
The first run pops an Automation permission dialog ("wants to control
Ghostty") — click Allow. Tabs are created in session-name order; the original
tab↔session arrangement isn't recorded anywhere, so it can't be reproduced
exactly. Per-tab fallback:

```bash
tmux-restore --pick      # list all sessions (with windows & status), then
                         # choose which to restore: numbers ("1 3" or "1,3"),
                         # Enter = all detached, q = cancel
tmux-restore --one       # attach the next unattached session here
tmux-restore <name>      # or attach a specific session by name
```

It's a plain executable invoked explicitly — no bashrc/zshrc hooks, so it works
with any shell.

**After a machine reboot** the tmux server itself is gone. The same commands
still work: the script starts tmux and waits for tmux-continuum to restore the
last autosave (every 5 min) — sessions, windows, per-pane directories and
on-screen text. **Running programs are not restarted**; each pane comes back as
a shell in its old directory (e.g. restart Claude Code with `claude --resume`).

## Working-directory inheritance (new windows/tabs keep your cwd)

Ghostty's `window-inherit-working-directory` needs the shell to **report** its
cwd (OSC 7). zsh/fish get this automatically; **macOS's `/bin/bash` (3.2) does
not support auto-injection**, and even Ghostty's own `ghostty.bash` gates its
hooks behind bash ≥ 4.4 — so for stock-bash users every new window started at
`$HOME`. Fix: one line in `~/.bashrc`:

```bash
[ -f ~/.ghostty-cwd.bash ] && source ~/.ghostty-cwd.bash
```

The snippet emits OSC 7 before each prompt, and inside tmux wraps it in a
passthrough envelope (`allow-passthrough on` is already in our tmux.conf) so
Ghostty sees the real directory even when you live in tmux.

## Key choices at a glance

| Item | Choice | Why |
|------|--------|-----|
| Terminal | Ghostty | GPU rendering, low memory, native splits |
| Prefix key | **Ctrl+b**, plus **Cmd+B** in Ghostty (sends `\x02`) | comfier to press; tmux untouched, Ctrl+b still works over ssh |
| Pane switching | **vi-style h/j/k/l** (arrows also work) | vim muscle memory |
| Persistence | tmux + resurrect + continuum | restore session/window/cwd across restarts |
| Parallel agents | one session per project, tasks per window | see docs/04 |

See `docs/` for the full rationale and background.
