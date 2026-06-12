# Coding Agents + tmux — Best-Practice Digest

> 中文:[04-agents-tmux.zh.md](./04-agents-tmux.zh.md)
> A digest of public practice (2026); the rationale behind this config.

## Why tmux

AI coding workflows shifted from "writing code" to "orchestrating + supervising
agents". Agent processes need exactly what tmux has had since 2007:

- **Session persistence**: long agent jobs must survive a closed laptop / dropped
  SSH. tmux is client-server; the session lives in a background process.
- **Process isolation + live output**: one agent per pane, isolated, visible.
- **Scriptable**: agents know `capture-pane` / `send-keys` — read other panes, send
  keys to other panes.

> In short: "a 2007 multiplexer became the runtime for 2026 AI agents."

## The hardest reason for Ghostty users ⚠️

Claude Code docs are explicit: **split-pane agent-teams mode is NOT supported in
Ghostty's native splits — it requires tmux or iTerm2**. `teammateMode` defaults to
`auto`: if you're inside tmux it enables split panes automatically.

## Recommended architecture: project → task, two levels

```
one project = one tmux session (named after the project)
  ├─ window: claude   main Claude Code
  ├─ window: dev      dev server (agents read its logs)
  └─ window: git      diffs
3–5 parallel agents is the sweet spot (matches official guidance).
```

## Parallel agents: git worktree + tmux

Each agent needs an **isolated filesystem sandbox** or they overwrite each other.
git worktrees give each branch its own directory while sharing git history.

Tooling: **workmux** (`brew install raine/workmux/workmux`) one-shots "create
worktree + open tmux window + inject prompt", plus `workmux dashboard` for status.

## Claude Code official Agent Teams (experimental)
- Enable: `"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}` in settings.json (v2.1.32+).
- One lead coordinates N teammates, each with its own context, messaging each other,
  sharing a task list.
- In tmux it auto-uses split panes, one pane per teammate.
- Practice: 3–5 teammates; 5–6 tasks each; different teammates own different files;
  start with research / PR review.

## Monitoring tools
| Tool | Purpose |
|------|---------|
| workmux dashboard | status of each worktree agent |
| tmux-agent-sidebar | tmux sidebar watching agent lifecycle hooks |
| NTM | tmux-wrapping orchestration: named sessions, broadcast prompts, conflict detection, TUI |

## Alternatives
- **Zellij**: modern tmux alternative (Rust), built-in layouts + session
  resurrection, friendlier out of the box; weaker remote ecosystem than tmux.
- **cmux** (manaflow-ai, libghostty-based): native terminal built for agents —
  vertical tabs, notification rings, session restore; claims "no tmux for Teams
  mode". Consider it if you'll switch terminals.
- **Snapshot tools**: gtab (lightweight named workspaces), crex/cmux-resurrect
  (auto-snapshot daemon, restores running processes), ghostty-workspace (declarative
  YAML). This repo chose tmux because it's true persistence, not recreation.

## Key tmux config points (already in ../tmux/tmux.conf)
- `allow-passthrough on` + `extended-keys on` + `terminal-features ...:extkeys` → notifications + Shift+Enter
- `default-terminal tmux-256color` + `terminal-overrides ...:RGB` → true color
- split/new-window with `-c "#{pane_current_path}"` → inherit cwd
- resurrect + continuum + `@continuum-restore on` → auto-restore across restarts

## Sources
- Claude Code official: Orchestrate teams of Claude Code sessions
- Will Ness / Hwee-Boon Yar — tmux + Claude Code practical configs
- raine/workmux — git worktrees + tmux parallel agents
- manaflow-ai/cmux — Ghostty-based agent terminal
- Ghostty Discussion #11479 — Ghostty, tmux and agents
