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
│   (gtmux CLI now lives in its own repo: github.com/chenchaoyi/gtmux —
│    install.sh installs it to ~/.local/bin/gtmux via its curl one-liner)
│   (agent-done notifications + click→exact-pane are provided by gtmux's own
│    hook; install.sh enables them via `gtmux install-hooks`)
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

## The `gtmux` CLI — command center for tmux sessions + coding agents

`gtmux` is the command center for your tmux sessions and the coding agents
running in them — **`agents`** (who's working / idle / waiting on you),
**`overview`** (sessions), **`restore`** (rebuild your tabs), **`focus`** (jump
to a tab/pane). It's a non-spawner: the radar + remote over whatever you already
run in tmux.

It's maintained in its **own repo — [github.com/chenchaoyi/gtmux](https://github.com/chenchaoyi/gtmux)** —
where the full CLI reference lives. `install.sh` (step 3) installs it for you via
its curl one-liner (a prebuilt, checksum-verified binary; GitHub-first with a CN
mirror fallback, no Go toolchain needed):

```sh
curl -fsSL https://raw.githubusercontent.com/chenchaoyi/gtmux/main/install.sh | bash
```

### How this workspace wires it in

gtmux is just a CLI; the bindings below live in this repo's `tmux/tmux.conf`
(and `set-titles-string '#S — #W'`, which `focus` reads to locate tabs):

| key | runs | what it does |
| --- | --- | --- |
| `prefix + g` | `gtmux overview --popup` | sessions/windows/panes popup, floats over any full-screen program |
| `prefix + a` | `gtmux agents --watch --popup` | live agent dashboard (↑/↓ select · Enter jump · q quit; closes on jump) |
| `prefix + G` | cheatsheet | the tmux key cheatsheet (`~/.tmux-cheatsheet.txt`) |
| `prefix + J` | `gtmux focus $(cat …/last-finished)` | jump to the pane of the agent that most recently finished |

After a Ghostty restart, run **`gtmux restore`** once in any tab to reattach
every tmux session to its own tab (after a reboot it also boots tmux and waits
for tmux-continuum — configured in `tmux.conf` — to restore the last autosave).
The `⏸ waiting` / `✓ latest` agent signals and click-to-jump notifications come
from gtmux's own hook, which `install.sh` enables via `gtmux install-hooks` (see
the next section).

**Menu-bar app (optional).** `install.sh` (step 8) also offers to install
**`Gtmux.app`** — a macOS status-bar icon showing live agent state (⏸ waiting /
⠿ working / ✳ idle + a count), click a row to jump to that pane. It's the GUI
form of `gtmux agents`, consuming the same data. Manage it with
`gtmux install-app [--login]` / `gtmux uninstall-app`.

See the [gtmux repo README](https://github.com/chenchaoyi/gtmux#readme) for the
full per-command docs (agent detection & `agents.json`, restore modes, `--json`,
mirror options, etc.).

## Agent-done notifications that click through to the exact pane (Claude Code)

Without tmux, Ghostty natively notifies when a Claude Code agent finishes and a
click jumps to its tab. **Under tmux that path is dead** — tmux drops the bare
notification escape. gtmux restores it (and lands on the **exact pane**) via its
built-in hook, which `install.sh` (step 7) enables for you with
**`gtmux install-hooks --yes`** — opt-in, since it edits `~/.claude/settings.json`
(backed up + idempotent, your other hooks preserved):

- A desktop notification fires when an agent finishes in **any** tmux session —
  including ones you aren't looking at — and **stays silent while you're already
  watching that session's Ghostty tab**.
- **Clicking it jumps straight to the precise pane.** gtmux generates a tiny
  helper app, **`GtmuxFocus.app`**, as the click target (on modern macOS a click
  can only *activate an app*, not run a command), which runs `gtmux focus --last`
  to land on the just-finished pane. First click prompts *"GtmuxFocus wants to
  control Ghostty"* — allow it once.
- **`prefix + J`** does the same jump from the keyboard.
- `terminal-notifier` makes the notification clickable — `install.sh` offers to
  `brew install` it (Enter to accept); without it you still get a plain banner.
- If peon-ping is present, `install.sh` silences peon's own desktop
  notifications (and `terminal_tab_title`) so you don't get double banners or a
  title fight with `set-titles`.

The hook itself (`gtmux hook`), the state files under `~/.local/share/gtmux/`,
and the notifier internals live in the [gtmux repo](https://github.com/chenchaoyi/gtmux);
`gtmux uninstall-hooks` reverses the setup.

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
| Workspace CLI | **one `gtmux`** (Go): `overview` · `agents` · `restore` · `focus` | one command for the whole workspace + multi-agent status; `--lang=en|zh` |
| What's running? | **prefix+g** session overview popup (also `gtmux overview` in any shell) | counts + per-session windows/panes at a glance |
| Agent-done alerts | gtmux's hook (`gtmux install-hooks`): notify on finish, **click → exact pane** (via `GtmuxFocus.app`); also `prefix+J` | restores Ghostty's click-through that tmux kills, lands on the precise pane; quiet when you're watching; peon-independent |
| Forgot a key? | **prefix+G** cheatsheet popup; prefix+? full list; prefix+/ then a key explains it | look it up without leaving tmux |
| Parallel agents | one session per project, tasks per window | see docs/04 |

See `docs/` for the full rationale and background.
