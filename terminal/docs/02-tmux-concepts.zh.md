# tmux 概念:server / session / window / pane

> English: [02-tmux-concepts.en.md](./02-tmux-concepts.en.md)

## 四层结构

tmux 是一棵树,从大到小四层:

```
server   后台一个常驻进程(你几乎不用直接管它)
└─ session   会话   ← 一个项目 / 一件大事
   └─ window  窗口   ← 一个"任务",类比浏览器的「标签页 Tab」
      └─ pane 窗格   ← 窗口里切分出来的小格子,类比一块「分屏」
```

| tmux 概念 | 类比 | 对应 Ghostty |
|-----------|------|--------------|
| **session** | 一个浏览器窗口 / 一个项目工作区 | 你为某项目开的一整套 |
| **window** | 浏览器的一个标签页 Tab | 类似 `cmd+t` 新标签 |
| **pane** | 标签页里的分屏小格 | 类似 `cmd+d` 分屏 |

## 关键点

- **session** 用项目名命名:`tmux new -s saas`。它里面所有 window 都属于这个 session。
- **window** 是 session 内部一个**全屏的工作标签**,有编号和名字(底部状态栏列成一排)。
  每个 window 里跑的进程独立,可同时活着,按数字键秒切。
- **pane** 是 window 内部的分屏小格。Claude Code 的 agent-teams 分屏 = 在一个 window 里切多个 pane。

```
session: saas(项目)
  ├─ window 0: claude    ← 全屏跑 Claude Code
  ├─ window 1: dev       ← 全屏跑 pnpm dev 看日志
  └─ window 2: git       ← 全屏看 diff
       └─ pane 1 | pane 2  ← 需要时再在某个 window 内分屏
```

## 两套标签/分屏并存的提醒

套上 tmux 后,Ghostty 自己的标签/分屏(`cmd+t`/`cmd+d`)和 tmux 的(`prefix c`/`prefix |`)会并存。
**建议:进了 tmux 就只用 tmux 的 window/pane,Ghostty 那层只留一个窗口当"画布"**,否则两套快捷键打架。

## 前缀键(prefix)

本配置**保留默认 `Ctrl+b`**。几乎所有 tmux 命令都是"先按前缀,松开,再按某键"。
本文里写的 `前缀 + x` = 先 `Ctrl+b` 再 `x`。常用命令见 [03-tmux-usage.zh.md](./03-tmux-usage.zh.md)。
