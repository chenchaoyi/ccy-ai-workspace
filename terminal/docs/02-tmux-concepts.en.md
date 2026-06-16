# tmux Concepts: server / session / window / pane

> 中文:[02-tmux-concepts.zh.md](./02-tmux-concepts.zh.md)

## The four-level tree

tmux is a tree, largest to smallest:

```
server    one background daemon (you rarely touch it directly)
└─ session    ← one project / one big effort
   └─ window  ← one "task"; like a browser Tab
      └─ pane ← a split cell inside a window; like a split pane
```

| tmux concept | Analogy | Ghostty equivalent |
|--------------|---------|--------------------|
| **session** | a browser window / a project workspace | the whole set you open for a project |
| **window** | a browser Tab | like `cmd+t` new tab |
| **pane** | a split cell inside a tab | like `cmd+d` split |

## Key points

- **session** is named after the project: `tmux new -s saas`. Every window inside
  belongs to that session.
- **window** is a **full-screen working tab** inside the session, with an index and
  name (listed in the status bar). Each window runs its own processes, all alive at
  once; jump with number keys.
- **pane** is a split cell inside a window. Claude Code's agent-teams split mode =
  multiple panes inside one window.

```
session: saas (project)
  ├─ window 0: claude    ← Claude Code full-screen
  ├─ window 1: dev       ← pnpm dev logs full-screen
  └─ window 2: git       ← diffs full-screen
       └─ pane 1 | pane 2  ← split a window further when needed
```

## Two tab/split systems coexist

With tmux on top, Ghostty's own tabs/splits (`cmd+t`/`cmd+d`) and tmux's
(`prefix c`/`prefix |`) both exist. Once inside tmux, use only tmux's windows/panes
and keep a single Ghostty window as the canvas. Otherwise the two keymaps clash.

## The prefix key

This config **keeps the default `Ctrl+b`**. Almost every tmux command is "press the
prefix, release, then press a key". In these docs `prefix + x` = `Ctrl+b` then `x`.
Common commands in [03-tmux-usage.en.md](./03-tmux-usage.en.md).
