# Recipes: Window Design for 3 Dev Scenarios + Browsing Code

> 中文:[05-workflows.zh.md](./05-workflows.zh.md)

## Golden rule: windows for "needs room", panes for "just a glance"

A laptop screen is small. Cramming many panes into one window makes Claude Code's
prompt and history feel tight. The principle:

- **Needs reading/typing room → give it a whole window** (Claude Code sessions,
  editors). A window is a full-screen tab; `prefix + number` switches instantly and
  is basically "free", so **prefer more windows over more panes**.
- **Only glanced at occasionally → use a pane** (dev server logs, git status, a
  scratch shell). Narrow is fine for logs.
- **`prefix + z` (zoom)** is your friend: even with a split, press z to temporarily
  full-screen the active pane to read history, press z again to restore.
- Keep **one maximized Ghostty window** as the canvas; let tmux own the layout so the
  two keymaps don't clash.
- Browse Claude history: `prefix + [` enters copy mode, `/` to search, `Ctrl-u/d` to
  page (50k-line scrollback configured).

> Rule of thumb: on a 13–14" laptop at a comfortable font, roughly **one Claude Code
> session full-width** reads comfortably. Two side-by-side panes each get half-width,
> and Claude's input box + history get cramped. So side-by-side is for *brief
> comparison only*; sustained work uses windows + zoom.

---

## Scenario 1: single project / single repo / one Claude Code

The common case. One maximized Ghostty window; a session named after the project;
windows split by *task*:

```
session: saas
├─ 0 claude   ← Claude Code, full window (where you live)
├─ 1 dev      ← dev server / test watch (Claude reads logs; you glance)
├─ 2 git      ← lazygit for diffs / commits
└─ 3 shell    ← scratch shell for ad-hoc commands (optional)
```

```bash
tmux new -s saas        # enter the session, lands on window 0
claude                  # run Claude Code in window 0
# prefix c to add dev, prefix c to add git; prefix 0/1/2/3 to flip instantly
```

Key: **don't split the claude window** — keep it full so history scrolls
comfortably. To peek at a file, hop to the shell window and `bat file`.

---

## Scenario 2: single repo / multiple Claude Code sessions (git worktrees)

Each worktree is an isolated directory; each Claude needs room → **give each Claude a
full window**, don't cram them into panes.

```bash
# in the main repo dir
git worktree add ../saas-feat-a feat-a
git worktree add ../saas-feat-b feat-b
tmux new -s saas
```

```
session: saas
├─ 0 main     ← main worktree: coordinate / review / git
├─ 1 feat-a   ← cd ../saas-feat-a && claude   (full window)
├─ 2 feat-b   ← cd ../saas-feat-b && claude   (full window)
└─ 3 dev      ← run servers when needed (use a different port per worktree)
```

Key points:
- `prefix + number` to flip between agents; each is full-screen, never cramped.
- Want to **watch two agents at once** (catch when one needs input)? Open a temporary
  "dashboard" window split into two panes, accept they're tight, and `prefix + z` to
  zoom the one you're acting on.
- The "create worktree + open window + inject prompt" flow is automated by **workmux**
  (`workmux add feat-a -p "..."`, `workmux dashboard`). See [04](./04-agents-tmux.en.md).
- Rename windows with `prefix + ,` (e.g. `feat-a`). Cursor can open each worktree dir directly.

---

## Scenario 3: one project / multiple interacting repos (e.g. web + api + shared lib)

Mental model: **window = repo.**

```
session: shop (project)
├─ 0 web      ← frontend repo: claude / edit
├─ 1 api      ← backend repo: claude / edit
├─ 2 shared   ← shared-lib repo
├─ 3 servers  ← one window split into two panes: web dev server | api dev server
│               (logs are glance-only; narrow panes are fine here)
└─ 4 git      ← lazygit (switch repo inside it)
```

Key points:
- Each repo gets its own window; **running servers** (glance-only logs) are most
  space-efficient merged into one `servers` window split into panes.
- Cross-repo coordinated change: a "coordinator Claude" in the main repo + a Claude per
  repo in their windows; or use agent-teams.
- The repos live as **sibling directories**; each window `cd`s into its repo. The
  session is still named after the project.

---

## When to open a new session vs a new window

**3–5 windows** per session is comfortable. Beyond that, or switching to a wholly
different project → `tmux new -s another-name`. `prefix + s` jumps between sessions,
`tmux ls` lists them. **Switch projects with sessions; switch tasks with windows.**

---

## Browsing repo structure & file contents in the terminal

Honestly: **for deep reading / go-to-definition / global search, an IDE (Cursor) is
still better — don't force everything into the terminal.** The value of terminal tools
is **a quick look without leaving / breaking flow while an agent runs.** A good set:

| Purpose | Tool | Notes |
|---------|------|-------|
| Directory tree | `eza --tree --level=2 --git-ignore` | nicer than ls/tree, respects .gitignore; or interactive `broot` |
| View a file | `bat file` | syntax-highlighted cat with line numbers + git gutter |
| Fuzzy find file/text | `fzf` + `ripgrep (rg)` | `rg term` to search; `fzf` to jump, `bat` as preview |
| File-manager TUI | `yazi` (or nnn / ranger) | arrow-key browse, bat preview, enter to open |
| Git browsing | `lazygit` | TUI for diffs / staging / history, great in the git window |
| In-terminal editing | `neovim` + telescope | if reducing Cursor dependence; otherwise keep Cursor |

Install (macOS): `brew install eza bat ripgrep fzf yazi lazygit`

**Positioning**: keep Cursor for deep reading / refactoring / multi-file navigation;
use `bat`/`eza`/`rg`/`fzf`/`lazygit`/`yazi` for "quick look while an agent runs". They
coexist fine — Cursor can open the same worktree/repo dirs tmux uses. Add a tmux `code`
window running `yazi` or `nvim` and you rarely leave the terminal just to glance at a file.

> Tip: Ghostty's `cmd+shift+up/down` (jump between prompts) works in bare Ghostty, but
> **once inside tmux** those marks may not pass through; to browse Claude history in
> tmux, use copy mode `prefix + [` then `/` search instead.
