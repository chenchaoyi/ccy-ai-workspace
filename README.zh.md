# ccy-ai-workspace

> 🌏 **English version: [README.md](./README.md)** · 以下为中文版。

个人的 AI / 开发工作区。可复现的配置与笔记，纳入版本管理，方便换机复原。

目前收录我的**终端环境**：**Ghostty + tmux**，针对 coding agent（Claude Code 等）做了调校。

完整配置、说明与一键复原：**[`terminal/`](./terminal/)**
([中文](./terminal/README.zh.md) · [English](./terminal/README.md))

---

## 为什么选 Ghostty(终端)

- **快且轻** —— GPU 加速渲染、占用内存低，可同时开多个 agent 会话。
- **原生分屏与标签** —— 简单场景无需多路复用器即可分屏/开标签。
- **Shell 集成** —— 追踪当前目录、在长 agent 日志里跳转命令提示符、agent 跑完/等输入时响铃提醒。
- **纯文本配置** —— 单个可读文件，易于版本化。

## 为什么在 Ghostty 之上再用 tmux

终端窗口是取景器；tmux 让**会话（session）**独立于窗口存活。agent 工作流需要这点：

- **持久化** —— session 活在后台进程里。合上笔记本、SSH 断线、退出 Ghostty：长任务照跑。重新接入即回到现场，**同一批活着的进程、同样的工作目录**。
- **进程隔离 + 可见性** —— 一个 agent 一个 pane，同时运行、输出实时。3–5 个 agent 并行，各占一个 window。
- **可脚本化** —— agent 懂 tmux（`capture-pane` / `send-keys`），能读别的 pane 输出或驱动它。
- **Claude Code 分屏版 Agent Teams 必需** —— 该模式需要 tmux（或 iTerm2）；Ghostty 原生分屏不支持。
- **跨重启恢复** —— 配 `tmux-resurrect` + `tmux-continuum`，布局与各 pane 的 cwd 自动回来。

## 基本概念(tmux)

四层树状结构:

```
server   后台一个常驻进程(几乎不用管)
└─ session   ← 一个项目        (命名:tmux new -s saas)
   └─ window ← 一个任务,像标签页(前缀 + c 创建)
      └─ pane← 分屏小格         (前缀 + | 或 -)
```

| 概念 | 类比 | 创建 / 切换 |
|------|------|-------------|
| **session** | 一个项目工作区 | `tmux new -s 名字` / `tmux attach -t 名字` |
| **window** | 浏览器标签页 | `前缀 + c` / `前缀 + n,p,0-9` |
| **pane** | 一块分屏 | `前缀 + \|` `-` / `前缀 + h,j,k,l` |

（这里的前缀是默认的 **`Ctrl+b`**：按下松开，再按下一个键。）

## 基本用法

```bash
# 一次装齐:先 brew 依赖,再配置 + gtmux
# (插件 / hook / 菜单栏 app 由 `gtmux doctor --fix` 收尾)
brew bundle --file=Brewfile
bash terminal/install.sh

# 为某项目起一个 session
tmux new -s saas
#   前缀 + c        新建 window(例如 claude / dev / git)
#   前缀 + |        左右分屏       前缀 + -   上下分屏
#   前缀 + h/j/k/l  在 pane 之间移动
#   前缀 + d        脱离(后台继续跑)
tmux attach -t saas   # 稍后回来——现场都还在
```

持久化是自动的（resurrect + continuum，上面的安装流程会装好插件）：布局与各 pane 的目录会在下次 tmux 启动时自动恢复。

## 实战场景 —— 三种工作流

> **黄金法则（笔记本屏幕）：** window 装需要空间的（Claude Code、编辑器），pane 只装瞟一眼的
> （日志、git status）。window 切换（`前缀 + 数字`）瞬间完成，所以**多开 window 优于多分 pane**。
> 读历史时用 `前缀 + z` 把 pane 临时全屏。完整分析 + 图示：
> **[docs/05-workflows](./terminal/docs/05-workflows.zh.md)** ([English](./terminal/docs/05-workflows.en.md))。

**1 —— 单仓库，单个 Claude Code。** 一个 Ghostty 窗口最大化；`tmux new -s saas`；按任务分 window
（别切分 claude 窗口）：

```
session saas:  0 claude(整窗)  1 dev(服务/日志)  2 git(lazygit)  3 shell
```

**2 —— 单仓库，多个 Claude（不同 git worktree）。** 每个 worktree 隔离，每个 agent 给整窗（不挤 pane）：

```
git worktree add ../saas-feat-a feat-a   # 每个特性重复一次
session saas:  0 main   1 feat-a(claude)   2 feat-b(claude)   3 dev
```
`前缀 + 数字` 在全屏 agent 间切；`workmux` 可一键完成搭建。

**3 —— 单项目，多仓库联动。** 心智：**window = 仓库**；把「只看日志」的服务合并到一个分 pane 的窗口：

```
session shop:  0 web   1 api   2 shared   3 servers(web|api 两 pane)   4 git
```

## 在终端里看代码

深度阅读/导航，IDE（Cursor）仍更强。想在 agent 跑着时快速查一眼，加这套：
`eza --tree`（结构）、`bat`（看文件）、`ripgrep` + `fzf`（搜索/跳转）、`lazygit`（git）、`yazi`（文件管理器）。
这些都已收进仓库根目录的 [`Brewfile`](./Brewfile)（`brew bundle --file=Brewfile`）。详见 [docs/05](./terminal/docs/05-workflows.zh.md)。

## 目录结构

```
ccy-ai-workspace/
├── README.md / README.zh.md   总览（英文 / 中文）
├── Brewfile                    全部 Homebrew 依赖，一条 `brew bundle` 装齐
└── terminal/                  Ghostty + tmux 配置、安装脚本、文档
    ├── ghostty/config
    ├── tmux/tmux.conf
    ├── install.sh
    └── docs/                  概念、用法、agent 最佳实践（中英）
```

每个选择背后的取舍与决策记录见 [`terminal/`](./terminal/)。
