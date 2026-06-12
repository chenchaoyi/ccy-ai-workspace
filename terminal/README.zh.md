# 终端工作环境(Ghostty + tmux + Coding Agent)

> 🌏 **English version: [README.md](./README.md)** · 以下为中文版。

我本地终端环境的**配置 + 用法 + 决策记录**,纳入版本管理,方便:
- 换一台新机器时**一键复原**;
- **分享**给同事直接抄。

## 目录结构

```
terminal/
├── README.md            英文版
├── README.zh.md         ← 你在这里:总览 + 一键复原
├── install.sh           一键软链配置到系统位置 + 装 tpm
├── ghostty/
│   └── config           Ghostty 配置(柔和暗色 / agent 友好)
├── tmux/
│   ├── tmux.conf        tmux 配置(保留默认 Ctrl+b 前缀)
│   └── cheatsheet.txt   前缀+g 弹窗显示的命令速查表
├── scripts/
│   └── tmux-restore     恢复 Ghostty ↔ tmux 工作现场(一键接回全部 session)
├── shell/
│   └── ghostty-cwd.bash macOS bash 3.2 的目录上报(让新窗口继承工作目录)
└── docs/
    ├── 01-ghostty.zh.md       Ghostty 配置说明 + 对比度/晃眼调校 + cwd 恢复结论
    ├── 02-tmux-concepts.zh.md tmux 概念:server / session / window / pane
    ├── 03-tmux-usage.zh.md     日常工作流:一项目一 session、window 布局、持久化
    ├── 04-agents-tmux.zh.md    Coding Agent + tmux 最佳实践汇总
    ├── 05-workflows.zh.md      三个实战场景 + 屏幕布局 + 终端看代码
    └── *.en.md                 每篇文档的英文版
```

## 一键复原(新机器)

```bash
# 前置:已装好 Ghostty(>= 1.3)和 tmux(>= 3.3)
#   brew install --cask ghostty ; brew install tmux
git clone git@github.com:chenchaoyi/ccy-ai-workspace.git
cd ccy-ai-workspace
bash terminal/install.sh --lang=zh    # 中文输出
bash terminal/install.sh              # English output(默认)
```

安装脚本会先检查两者是否存在及版本是否达标;有新版可用时会(在询问确认后)
帮你执行 `brew upgrade`。参数:`--lang=en|zh` 输出语言、`-y/--yes` 自动确认
所有询问(对 agent/CI 友好;不带时非交互运行也绝不阻塞)、`-h/--help` 完整
帮助(含输出标记与退出码说明)。

脚本会**拷贝**配置到:
- `~/.config/ghostty/config`
- `~/.tmux.conf`
- `~/.local/bin/tmux-restore`(命令行工具,任意目录可调用,见下文 ——
  刻意【不】写进任何 shell 的 rc 文件,所以无论你用 bash/zsh/fish 都能用)
- `~/.ghostty-cwd.bash`(仅 bash 用户需要 —— 见下文"新窗口继承工作目录")

并克隆 tpm。已存在的旧文件会自动备份成 `*.bak.<时间戳>`。

> 用拷贝而非软链:这些配置很少改动,直接拷贝更简单、不易乱套。在 repo 里改完后,
> **重跑 `bash terminal/install.sh`** 即可应用。

## 装完之后

1. **Ghostty**:重开,或窗口内按 `Cmd+Shift+,` 重载。
2. **tmux**:启动 `tmux` → 按 `Ctrl+b` 然后 `I`(大写)安装插件。
3. **验证持久化**:`Ctrl+b` 然后 `Ctrl-s` 手动存一次;重启 tmux 应自动恢复布局与各窗格目录。

## 接回 tmux session(`tmux-restore`)

quit Ghostty 后 tmux server 和所有 session 都还活着,消失的只是 Ghostty 的
tab。重开 Ghostty 后,在任意 tab 里运行**一次**:

```bash
tmux-restore             # 每个 session 一个 tab,一次全部接回
```

它通过 Ghostty 1.3+ 的原生 AppleScript 能力,为每个 session 开一个 tab 并全部
attach;你运行命令的那个 tab 复用给第一个 session;`window-save-state` 恢复
出来的多余空白 tab 直接 Cmd+W 关掉即可。首次运行会弹出自动化授权("想要控制
Ghostty"),点允许即可。tab 按 session 名字顺序创建 —— 原来"哪个 tab 对应
哪个 session"没有任何地方记录,无法精确复原顺序。
也可以在单个 tab 里逐个接:

```bash
tmux-restore --pick      # 列出所有 session(含 window 和连接状态),自己选:
                         # 输编号("1 3" 或 "1,3"),回车=全部待接回,q=取消
tmux-restore --one       # 当前 tab 接回下一个无人连接的 session
tmux-restore <名字>       # 或按名字 attach 指定 session
```

它是个显式调用的普通可执行脚本 —— 不碰 bashrc/zshrc,换什么 shell 都能用。

**电脑意外重启后** tmux server 本身也没了,同样的命令依然适用:脚本会启动
tmux 并等 tmux-continuum 恢复最近一次自动存档(每 5 分钟存一次)——
session/window 结构、各 pane 的目录和屏幕文本都会回来。**正在运行的程序不会
自动重启**,每个 pane 恢复成停在原目录的 shell(比如 Claude Code 用
`claude --resume` 重新拉起)。

## 新窗口继承工作目录

Ghostty 的 `window-inherit-working-directory` 生效的前提是 shell 主动**上报**
当前目录(OSC 7)。zsh/fish 由 Ghostty 自动注入;**macOS 自带的 `/bin/bash`
(3.2)不支持自动注入**,连官方 `ghostty.bash` 的钩子都要求 bash ≥ 4.4 ——
所以原生 bash 用户的新窗口永远从家目录开始。修复只需在 `~/.bashrc` 加一行:

```bash
[ -f ~/.ghostty-cwd.bash ] && source ~/.ghostty-cwd.bash
```

该片段在每次出 prompt 前上报 OSC 7;在 tmux 里会包一层透传信封(我们的
tmux.conf 已开 `allow-passthrough on`),常驻 tmux 时 Ghostty 也能拿到真实目录。

## 核心选择速记

| 项 | 选择 | 为什么 |
|----|------|--------|
| 终端 | Ghostty | GPU 渲染、省内存、原生分屏 |
| 前缀键 | **Ctrl+b**,Ghostty 里另配 **Cmd+B**(发送 `\x02`) | 按起来更舒服;tmux 零改动,ssh 下 Ctrl+b 照常可用 |
| pane 切换 | **vi 风格 h/j/k/l**(方向键也可) | 习惯 vim 手感 |
| 持久化 | tmux + resurrect + continuum | 跨重启恢复 session/window/cwd,比快照工具更彻底 |
| 忘了按键? | **前缀+g** 速查表弹窗;前缀+? 全量键位;前缀+/ 再按某键=解释它 | 不离开 tmux 随手查 |
| 并行 agent | 一项目一 session,任务分 window | 见 docs/04 |

详细取舍与背景见 `docs/`。
