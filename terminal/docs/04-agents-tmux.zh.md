# Coding Agent + tmux 最佳实践汇总

> English: [04-agents-tmux.en.md](./04-agents-tmux.en.md)
> 这是对公开实践的调研汇总(2026),作为本配置背后的理念依据。

## 为什么是 tmux

AI coding agent 的工作流从"自己写代码"变成"编排 + 监督多个 agent"。agent 进程的刚需,
恰好是 tmux 从 2007 年就有的能力:

- **会话持久**:agent 任务跑很久,关笔记本/SSH 断线都不能让它死。tmux 是 client-server,session 活在后台。
- **进程隔离 + 实时输出**:每个 agent 一个 pane,互不干扰、输出可见。
- **可脚本化**:agent 自己懂 `capture-pane` / `send-keys`,能读别的 pane、给别的 pane 发命令。

> 一句话:"2007 年的多路复用器,成了 2026 年 AI agent 的运行时(runtime)。"

## 对 Ghostty 用户最硬的一条理由 ⚠️

Claude Code 官方文档明确:**split-pane 的 agent-teams 分屏在 Ghostty 原生分屏下不支持,
必须用 tmux 或 iTerm2**。`teammateMode` 默认 `auto`:检测到在 tmux 里就自动启用分屏。

## 推荐架构:按"项目—任务"两层

```
一个项目 = 一个 tmux session(项目名命名)
  ├─ window: claude   主 Claude Code
  ├─ window: dev      dev server(让 agent 读日志)
  └─ window: git      看 diff
3–5 个并行 agent 是甜区(官方同此);再多协调开销 > 收益。
```

## 并行多 agent:git worktree + tmux

每个 agent 需要**独立的文件系统沙箱**,否则同目录互相覆盖。git worktree 给每个分支独立目录、共享 git 历史。

工具化:**workmux**(`brew install raine/workmux/workmux`)把"建 worktree + 开 tmux window + 喂 prompt"一键化,
还有 `workmux dashboard` 看各 agent 状态。

## Claude Code 官方 Agent Teams(实验)
- 开启:`settings.json` 里 `"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}`(需 v2.1.32+)。
- 一个 lead 协调 + 多个 teammate,各自独立 context、互相直接发消息、共享任务列表。
- 在 tmux 里自动走分屏,每个 teammate 一个 pane。
- 实践:3–5 个 teammate;每人 5–6 任务;不同 teammate 拥有不同文件避免冲突;从"研究/审查 PR"起步。

## 监控工具
| 工具 | 作用 |
|------|------|
| workmux dashboard | 看各 worktree agent 状态 |
| tmux-agent-sidebar | tmux 侧边栏,监听 agent 生命周期 hook |
| NTM | 包装 tmux 的 agent 编排:命名 session、广播 prompt、冲突检测、TUI 看板 |

## 替代方案
- **Zellij**:tmux 的现代替代(Rust),内置布局 + 会话恢复,开箱更友好;远程生态不如 tmux。
- **cmux**(manaflow-ai,基于 libghostty):专为 agent 造的原生终端,垂直 tabs、通知环、会话恢复,
  号称 "Teams 模式无需 tmux"。愿意换终端可考虑。
- **快照工具**:gtab(轻量命名工作区)、crex/cmux-resurrect(守护进程自动快照、可恢复运行进程)、
  ghostty-workspace(声明式 YAML)。本仓库选 tmux,因为它是真持久化而非重建。

## 关键 tmux 配置点(已落地在 ../tmux/tmux.conf)
- `allow-passthrough on` + `extended-keys on` + `terminal-features ...:extkeys` → 通知透传 & Shift+Enter
- `default-terminal tmux-256color` + `terminal-overrides ...:RGB` → 真彩色
- split/new-window 带 `-c "#{pane_current_path}"` → 继承当前目录
- resurrect + continuum + `@continuum-restore on` → 跨重启自动恢复

## 来源
- Claude Code 官方:Orchestrate teams of Claude Code sessions
- Will Ness / Hwee-Boon Yar — tmux + Claude Code 实战配置
- raine/workmux — git worktree + tmux 并行 agent
- manaflow-ai/cmux — 基于 Ghostty 的 agent 终端
- Ghostty Discussion #11479 — Ghostty, tmux and agents
