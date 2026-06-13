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
│   ├── gtmux            one CLI for the Ghostty↔tmux workspace:
│   │                      restore (reattach all) · overview (prefix+g popup) · focus (jump to a tab)
│   └── claude-notify    Claude Code hook: agent-done desktop notification, click → gtmux focus
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
- `~/.local/bin/gtmux` (CLI, callable from any directory — see below;
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
(`gtmux restore`) and the picture comes back.

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
the display** — sessions keep running and `gtmux restore` reattaches them
anytime; a reboot kills the server too, but continuum's 5-minute autosaves
restore the layout (see below). Full concept guide: `docs/02-tmux-concepts.en.md`.

Corollary: **names belong in the state layer too.** Ghostty tab titles are
configured to mirror "session — window" automatically (tmux `set-titles`),
so they come back correct after a reattach; don't rename Ghostty tabs by hand
(it gets overridden, and is lost on quit anyway) — rename the session
(`tmux rename-session`) or window (`prefix+,`) instead. This name-on-the-tab
binding is also what lets `gtmux focus <session>` jump straight to a tab — the
write side (`set-titles`) and the read side (`focus`) are one feature.

## The `gtmux` CLI — one command for the Ghostty↔tmux workspace

`gtmux` drives Ghostty from the tmux state layer. One command, three verbs —
**`restore`** (build tabs), **`overview`** (see state), **`focus`** (jump to a
tab) — covering a tab's whole life. It's a plain executable invoked explicitly
(no bashrc/zshrc hooks), so it works with any shell. Run bare `gtmux` for the
overview.

### `gtmux restore` — reattach sessions to tabs

Quitting Ghostty leaves the tmux server and all sessions alive — only the
Ghostty tabs are gone. After reopening Ghostty, run **once** in any tab:

```bash
gtmux restore            # one Ghostty tab per tmux session, all attached
```

It opens one tab per session (via Ghostty 1.3+'s native AppleScript support)
and attaches them all; the tab you ran it in takes the first session. Leftover
blank tabs restored by `window-save-state` can just be closed (Cmd+W). The
first run pops an Automation permission dialog ("wants to control Ghostty") —
click Allow. Tabs are created in session-name order; the original tab↔session
arrangement isn't recorded anywhere, so it can't be reproduced exactly. Per-tab
fallback:

```bash
gtmux restore --pick     # list all sessions (with windows & status), then
                         # choose which: numbers ("1 3" or "1,3"),
                         # Enter = all detached, q = cancel
gtmux restore --one      # attach the next unattached session here
gtmux restore <name>     # or attach a specific session by name
```

**After a machine reboot** the tmux server itself is gone. `gtmux restore`
still works: it starts tmux and waits for tmux-continuum to restore the last
autosave (every 5 min) — sessions, windows, per-pane directories and on-screen
text. **Running programs are not restarted**; each pane comes back as a shell
in its old directory (e.g. restart Claude Code with `claude --resume`).

### `gtmux overview` — see what's running (also `prefix+g`)

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

▶ current  ● attached  ○ detached   * active  Z zoomed  • new output   (jump: gtmux focus <name>)
```

This works because tmux intercepts the prefix before the foreground program
sees it. The same summary is available from any shell: `gtmux overview` (or
just `gtmux`). The key cheatsheet lives next door on **`prefix + G`**.

### `gtmux focus <name>` — jump to a session's tab

```bash
gtmux focus shop         # bring the Ghostty tab showing session "shop" to front
```

This is the read side of `set-titles`: because each tab title is
"session — window", `focus` finds the tab whose title matches `<name>` and
runs Ghostty's AppleScript `select tab` + `activate`. Handy on its own ("jump
to that project"), and it's the hook a desktop-notification click can call to
land you on the right tab when a background agent finishes.

> Needs `set-titles` to stay authoritative over tab titles. If another tool
> writes the tab title too (e.g. peon-ping's `terminal_tab_title`), turn that
> off so titles stay in the "session — window" format `focus` matches on.

## Agent-done notifications that click through to the tab (Claude Code)

Without tmux, Ghostty shows a native notification when a Claude Code agent
finishes and clicking it jumps to that tab. **Under tmux that path is dead** —
tmux drops the bare notification escape, and a backgrounded/detached session
has no tab to surface. `claude-notify` (a Claude Code hook installed by
`install.sh`) restores it, and works whether or not you use peon-ping:

- Fires a desktop notification when an agent finishes in **any** tmux
  session — including ones you aren't looking at — and **stays silent when
  you're already watching that session's Ghostty tab**.
- With **`terminal-notifier`** the notification is **clickable — the click runs
  `gtmux focus <session>`** and lands you on the right tab. The installer offers
  to `brew install` it. Without it you still get a reliable native banner, just
  not clickable (macOS has no zero-dependency clickable notification); it puts
  the session name in the text so you can `gtmux focus <name>` yourself.
- Self-contained — no plugin dependency. If peon-ping is present, the installer
  offers to silence peon's own desktop notifications (and `terminal_tab_title`)
  so you don't get double banners or a title fight with `set-titles`.

It's **opt-in**: `install.sh`'s last step asks before enabling it, because
wiring it edits `~/.claude/settings.json` (backed up, idempotent, your other
hooks preserved). Run the installer again anytime to turn it on.

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
| Tab naming | name sessions/windows in tmux; **`set-titles` mirrors them onto Ghostty tabs** | titles live in the state layer — survive quit/reboot, auto-correct after `gtmux restore`, zero manual renaming |
| Workspace CLI | **one `gtmux`**: `restore` (reattach) · `overview` (prefix+g popup) · `focus <name>` (jump to a tab) | one command, three verbs; `focus` reads the `set-titles` titles to land on the right tab |
| What's running? | **prefix+g** session overview popup (also `gtmux overview` in any shell) | counts + per-session windows/panes at a glance |
| Agent-done alerts | **`claude-notify`** hook: notify on finish, **click → `gtmux focus`** | restores Ghostty's click-through notification that tmux otherwise kills; quiet when you're watching; peon-independent |
| Forgot a key? | **prefix+G** cheatsheet popup; prefix+? full list; prefix+/ then a key explains it | look it up without leaving tmux |
| Parallel agents | one session per project, tasks per window | see docs/04 |

See `docs/` for the full rationale and background.
