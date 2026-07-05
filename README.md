# ccy-ai-workspace

> 🌏 **中文版见 [README.zh.md](./README.zh.md)** · English below.

Personal AI / dev workspace. Reproducible configs and notes, version-controlled for
restoring on a new machine.

Currently holds my **terminal environment**: **Ghostty + tmux**, tuned for coding
agents (Claude Code & friends).

Full setup, configs, one-command restore: **[`terminal/`](./terminal/)**
([中文](./terminal/README.zh.md) · [English](./terminal/README.md))

---

## Why Ghostty (the terminal)

- **Fast & light** — GPU-accelerated rendering, low memory; runs many agent sessions at once.
- **Native splits & tabs** — built-in panes/tabs without a multiplexer for simple cases.
- **Shell integration** — tracks cwd, jumps between prompts in long agent logs, rings
  the bell when an agent finishes / waits for input.
- **Plain-text config** — a single readable file, easy to version.

## Why tmux (on top of Ghostty)

The terminal window is a viewport; tmux makes the **session** survive independently
of it. Agent workflows need this:

- **Persistence** — sessions live in a background process. Close the laptop, drop SSH,
  quit Ghostty: long agent jobs keep running. Reattach to the same live processes and
  working directories.
- **Process isolation + visibility** — one agent per pane, all running at once, output
  live. Run 3–5 agents in parallel, each in its own window.
- **Scriptable** — agents understand tmux (`capture-pane`, `send-keys`), so they can
  read another pane's output or drive it.
- **Required for Claude Code split-pane "Agent Teams"** — that mode needs tmux (or
  iTerm2); Ghostty's native splits don't support it.
- **Restore across reboots** — with `tmux-resurrect` + `tmux-continuum`, layout and
  each pane's cwd come back automatically.

## Core concepts (tmux)

A four-level tree:

```
server   one background daemon (you rarely touch it)
└─ session   ← one project          (named: tmux new -s saas)
   └─ window ← one task; like a Tab  (prefix + c to create)
      └─ pane← a split cell          (prefix + | or -)
```

| Concept | Analogy | Create / switch |
|---------|---------|-----------------|
| **session** | a project workspace | `tmux new -s name` / `tmux attach -t name` |
| **window** | a browser tab | `prefix + c` / `prefix + n,p,0-9` |
| **pane** | a split | `prefix + \|` `-` / `prefix + h,j,k,l` |

(The prefix here is the default **`Ctrl+b`**: press it, release, then the next key.)

## Basic usage

```bash
# install everything onto a machine: brew deps, then configs + gtmux
# (plugins / hooks / menu-bar app are finished by `gtmux doctor --fix`)
brew bundle --file=Brewfile
bash terminal/install.sh

# start a session for a project
tmux new -s saas
#   prefix + c   new window (e.g. claude / dev / git)
#   prefix + |   split left/right    prefix + -   split top/bottom
#   prefix + h/j/k/l   move between panes
#   prefix + d   detach (keeps running in background)
tmux attach -t saas   # come back later — everything still there
```

Persistence is automatic (resurrect + continuum, installed by the setup above):
layout and each pane's directory restore on the next tmux start.

## Recipes — three workflows

> **Golden rule (laptop screens):** windows for things that need room (Claude Code,
> editors); panes only for things you glance at (logs, git status). Window switching
> (`prefix + number`) is instant, so **prefer more windows over more panes**. Use
> `prefix + z` to zoom a pane full-screen when reading. Full analysis + diagrams:
> **[docs/05-workflows](./terminal/docs/05-workflows.en.md)** ([中文](./terminal/docs/05-workflows.zh.md)).

**1 — Single repo, one Claude Code session.** One maximized Ghostty window;
`tmux new -s saas`; split by task into windows (don't split the claude window):

```
session saas:  0 claude (full)   1 dev (server/logs)   2 git (lazygit)   3 shell
```

**2 — Single repo, multiple Claude sessions on git worktrees.** Each worktree is
isolated; give each agent its own full window (not panes):

```
git worktree add ../saas-feat-a feat-a   # repeat per feature
session saas:  0 main   1 feat-a (claude)   2 feat-b (claude)   3 dev
```
`prefix + number` flips between full-screen agents; `workmux` can automate the setup.

**3 — One project, multiple interacting repos.** Mental model **window = repo**;
merge glance-only servers into one paned window:

```
session shop:  0 web   1 api   2 shared   3 servers(web|api panes)   4 git
```

## Browsing code in the terminal

For deep reading/navigation, an IDE (Cursor) is still better. For a quick look while
an agent runs, add: `eza --tree` (structure), `bat` (view files), `ripgrep` + `fzf`
(search/jump), `lazygit` (git), `yazi` (file manager). All included in the
repo-root [`Brewfile`](./Brewfile) (`brew bundle --file=Brewfile`). Details in
[docs/05](./terminal/docs/05-workflows.en.md).

## Layout

```
ccy-ai-workspace/
├── README.md / README.zh.md   overview (EN / 中文)
├── Brewfile                    every Homebrew dep in one `brew bundle`
└── terminal/                  Ghostty + tmux configs, install script, docs
    ├── ghostty/config
    ├── tmux/tmux.conf
    ├── install.sh
    └── docs/                  concepts, usage, agent best-practices (EN + 中文)
```

See [`terminal/`](./terminal/) for details and the decision log behind each choice.
