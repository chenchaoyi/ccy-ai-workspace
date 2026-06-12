# 实战:三种开发场景的窗口设计 + 终端看代码

> English: [05-workflows.en.md](./05-workflows.en.md)

## 黄金法则:window 装"需要空间的",pane 装"只瞟一眼的"

笔记本屏幕有限,一个窗口塞太多 pane/子窗口,Claude Code 的对话框和历史会很局促。原则:

- **需要阅读/打字空间的 → 给整块 window**(Claude Code 会话、编辑器)。window 是全屏标签,
  `前缀 + 数字` 瞬间切换、几乎"免费",**多开几个 window 优于多分 pane**。
- **只是偶尔瞟一眼的 → 才用 pane**(dev server 日志、git status、临时 shell)。日志窄点无所谓。
- **`前缀 + z` 缩放**是你最好的朋友:即使分了 pane,按 z 把当前 pane 临时全屏读历史,再按 z 还原。
- Ghostty 只留**一个最大化窗口**当画布,布局都交给 tmux,避免两套快捷键打架。
- 浏览 Claude 历史:`前缀 + [` 进复制模式,`/` 搜索、`Ctrl-u/d` 翻页(已配 5 万行缓冲)。

> 经验值:13–14" 笔记本舒适字号下,大约只够**一个 Claude Code 会话占满宽度**才看得舒服。
> 横向并两个 pane、各自半宽,Claude 的输入框和历史就挤了。所以并排只用于"短暂对照",
> 长时间工作靠 window + zoom。

---

## 场景一:单项目 / 单仓库 / 单个 Claude Code

最常见。一个 Ghostty 窗口最大化,按项目名建 session,再按"任务"分 window:

```
session: saas
├─ 0 claude   ← Claude Code,整窗全屏(你主要待这儿)
├─ 1 dev      ← dev server / 测试 watch(Claude 可读日志,你瞟一眼)
├─ 2 git      ← lazygit 看 diff / 提交
└─ 3 shell    ← 自己跑命令的临时 shell(可选)
```

```bash
tmux new -s saas        # 进入 session,默认在 0 号 window
claude                  # 在 0 号跑 Claude Code
# 前缀 c 建 dev,前缀 c 建 git,各窗口启动对应程序;前缀 0/1/2/3 秒切
```

要点:**不要切分 claude 窗口**,让它整窗,历史滚动舒服。要看某文件就去 shell 窗口 `bat 文件`。

---

## 场景二:单仓库 / 多个 Claude Code(不同 git worktree)

每个 worktree 是隔离目录,每个 Claude 都要空间 → **每个 Claude 给一个整 window**,不要挤 pane。

```bash
# 在主仓库目录
git worktree add ../saas-feat-a feat-a
git worktree add ../saas-feat-b feat-b
tmux new -s saas
```

```
session: saas
├─ 0 main     ← 主 worktree:协调 / review / git
├─ 1 feat-a   ← cd ../saas-feat-a && claude   (整窗)
├─ 2 feat-b   ← cd ../saas-feat-b && claude   (整窗)
└─ 3 dev      ← 需要时跑服务(注意每个 worktree 用不同端口)
```

要点:
- `前缀 + 数字` 在各 agent 间切,每个都全屏,不局促。
- 想**同时盯**两个 agent(等其中一个要输入)?临时开一个"看板"window 横分两 pane,
  但接受它俩偏挤,用 `前缀 + z` 放大正在操作的那个。
- 这套"建 worktree + 开 window + 喂 prompt"可用 **workmux** 一键化
  (`workmux add feat-a -p "..."`、`workmux dashboard` 看状态)。详见 [04](./04-agents-tmux.zh.md)。
- 给 window 改名:`前缀 + ,`,改成 feat-a 这种。Cursor 想看代码可直接打开各 worktree 目录。

---

## 场景三:单项目 / 多仓库联动(如 web + api + 共享库)

推荐心智:**window = 仓库**。

```
session: shop(项目)
├─ 0 web      ← 前端仓库:claude / 编辑
├─ 1 api      ← 后端仓库:claude / 编辑
├─ 2 shared   ← 共享库仓库
├─ 3 servers  ← 一个窗口里横分两 pane:web dev server | api dev server
│               (日志只瞟,窄点无所谓,正适合 pane)
└─ 4 git      ← lazygit(在里面切仓库)
```

要点:
- 每个仓库各占一个 window;**正在跑的服务**这种"只看日志"的,合并到一个 `servers` 窗口分 pane 最省地方。
- 跨仓库协同改动:主仓库放一个"协调 Claude" + 各仓库自己的 Claude;或用 agent-teams。
- 多个仓库作为**同级目录**存在,各 window `cd` 进各自仓库;session 仍按项目命名。

---

## 何时开新 session,而不是新 window

一个 session 里 **3–5 个 window** 最舒服。超过、或切到完全不同的项目 → 新开 `tmux new -s 另一个名字`。
`前缀 + s` 在 session 间跳,`tmux ls` 总览。**项目维度用 session 切,任务维度用 window 切。**

---

## 在终端里看代码结构与文件内容

说实话:**深度读代码 / 跳转定义 / 全局搜索,IDE(Cursor)仍然更强,不必硬塞进终端。**
终端工具的价值是:**agent 正在跑时,你不切走、不打断心流地快速查一眼。**

| 用途 | 工具 | 说明 |
|------|------|------|
| 目录树 | `eza --tree --level=2 --git-ignore` | 比 ls/tree 好看、懂 .gitignore;或交互式 `broot` |
| 看文件 | `bat 文件` | 语法高亮 + 行号 + git 标记的 cat |
| 模糊找文件/内容 | `fzf` + `ripgrep (rg)` | `rg 关键词` 全局搜;`fzf` 跳文件,`bat` 做预览 |
| 文件管理器 TUI | `yazi`(或 nnn / ranger) | 方向键浏览、bat 预览、回车打开 |
| Git 浏览 | `lazygit` | diff / 暂存 / 历史的 TUI,放 git 窗口里极顺手 |
| 终端内编辑 | `neovim` + telescope | 想减少对 Cursor 依赖时用;否则保留 Cursor |

安装(macOS):`brew install eza bat ripgrep fzf yazi lazygit`

**定位建议**:Cursor 留给"深读 / 重构 / 多文件导航";终端配 `bat`/`eza`/`rg`/`fzf`/`lazygit`/`yazi`
用于"agent 跑着时快速查一眼"。两者并存无冲突——Cursor 可直接打开 tmux 里各 worktree/仓库目录。
再加一个 tmux `code` 窗口跑 `yazi` 或 `nvim`,基本就不用为"瞄一眼文件"而离开终端了。

> 小贴士:Ghostty 的 `cmd+shift+上/下` 跳命令提示符在裸 Ghostty 里好用,但**套了 tmux 后**
> 标记可能不透传;在 tmux 里浏览 Claude 历史,改用复制模式 `前缀 + [` 再 `/` 搜索更稳。
