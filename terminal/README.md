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
│   ├── tmux.conf        tmux config (keeps default Ctrl+b prefix)
│   └── cheatsheet.txt   quick reference shown by the prefix+g popup
├── scripts/
│   ├── tmux-restore     restore the Ghostty ↔ tmux workspace (reattach all sessions)
│   └── tmux-overview    session/window/pane summary (prefix+g popup, or run anywhere)
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
bash terminal/install.sh              # English output (default)
bash terminal/install.sh --lang=zh    # 中文输出
```

The installer checks both tools' presence and versions up front (and offers a
`brew upgrade` — after asking — when a newer one is available). Flags:
`--lang=en|zh` output language, `-y/--yes` auto-confirm prompts (agent/CI
friendly; without it non-interactive runs never block), `-h/--help` full help
including output markers and exit codes.

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

## Background: how Ghostty and tmux concepts fit together

The most confusing part: **Ghostty and tmux each have their own "window" —
and they are completely different things**. One-line analogy: **Ghostty is
the monitor, tmux is the computer**. Unplug the monitor (quit Ghostty) and
everything inside the computer (sessions) keeps running; plug it back in
(`tmux-restore`) and the picture comes back.

**Top layer — Ghostty, the "display" (GUI app, gone on Cmd+Q):**

```text
┌─ Ghostty window (macOS window, Cmd+N) ──────────┐
│  tab bar (Cmd+T):   [ blog ]   [ shop ]          │
│ ┌─────────────────────────────────────────────────┐
│ │                                                 │
│ │   the active tab's content area = whatever      │
│ │   the tmux session it is attached to shows      │
│ │                                                 │
│ └─────────────────────────────────────────────────┘
└──────────────────────────────────────────────────┘
        │ tab[blog] attaches         │ tab[shop] attaches
        ▼                            ▼
```

**Bottom layer — tmux, the "state" (background process, survives quit):**

```text
tmux server (exactly one per machine, holds ALL the state)
├── session "blog"                ← ≈ one project's workspace
│   ├── window 0 "code"           ← ≈ one task (shown in the status bar)
│   │   ├── pane: claude          ← splits inside a window
│   │   └── pane: vim
│   └── window 1 "logs"
│       └── pane: tail -f
└── session "shop"                ← another project, attached by tab[shop]
    └── window 0 "dev"
```

The five concepts side by side:

| Concept | Belongs to | Analogy | Created with |
|---------|-----------|---------|--------------|
| window | Ghostty | a monitor | `Cmd+N` |
| tab | Ghostty | a "channel" on the monitor, usually viewing one session | `Cmd+T` |
| session | tmux | a project's whole workspace | `tmux new -s name` |
| window | tmux | one task inside the project (visible in the status bar) | `prefix+c` |
| pane | tmux | a split inside the task's screen | `prefix+\|` / `prefix+-` |

Lifecycle in one line: closing a tab or quitting Ghostty **only disconnects
the display** — sessions keep running and `tmux-restore` reattaches them
anytime; a reboot kills the server too, but continuum's 5-minute autosaves
restore the layout (see below). Full concept guide: `docs/02-tmux-concepts.en.md`.

Corollary: **names belong in the state layer too.** Ghostty tab titles are
configured to mirror "session — window" automatically (tmux `set-titles`),
so they come back correct after a reattach; don't rename Ghostty tabs by hand
(it gets overridden, and is lost on quit anyway) — rename the session
(`tmux rename-session`) or window (`prefix+,`) instead.

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

## Live session overview (`prefix+g`, or `tmux-overview`)

Press **`prefix + g`** anywhere — even while a full-screen program (Claude
Code, vim, …) is running — and a size-fitted popup floats over it without
interrupting anything; any key closes it:

```
tmux overview — 2 sessions · 3 windows · 5 panes

▶ ccy-ai-workspace     1 window · 1 pane
    0: ccy-ai-workspace *  (1 pane)

● tryout3              2 windows · 4 panes
    0: wifiscope  (1 pane)
    1: claude code *  (3 panes)

▶ current  ● attached  ○ detached   * active  Z zoomed  • new output
```

This works because tmux intercepts the prefix before the foreground program
sees it. The same summary is available as a CLI from any shell:
`tmux-overview`. The key cheatsheet lives next door on **`prefix + G`**.

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
| Tab naming | name sessions/windows in tmux; **`set-titles` mirrors them onto Ghostty tabs** | titles live in the state layer — survive quit/reboot, auto-correct after `tmux-restore`, zero manual renaming |
| What's running? | **prefix+g** session overview popup (also `tmux-overview` in any shell) | counts + per-session windows/panes at a glance |
| Forgot a key? | **prefix+G** cheatsheet popup; prefix+? full list; prefix+/ then a key explains it | look it up without leaving tmux |
| Parallel agents | one session per project, tasks per window | see docs/04 |

See `docs/` for the full rationale and background.
