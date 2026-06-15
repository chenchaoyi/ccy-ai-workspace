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
│   (gtmux 命令行已拆成独立仓库:github.com/chenchaoyi/gtmux ——
│    install.sh 用它的 curl 一行命令装到 ~/.local/bin/gtmux)
├── scripts/
│   └── claude-notify    Claude Code 钩子:agent 完成弹通知,点击→ 确切 pane(install.sh 生成 GtmuxFocus.app)
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
- `~/.local/bin/gtmux`(命令行工具,任意目录可调用,见下文 ——
  刻意【不】写进任何 shell 的 rc 文件,所以无论你用 bash/zsh/fish 都能用)
- `~/.ghostty-cwd.bash`(仅 bash 用户需要 —— 见下文"新窗口继承工作目录")

并克隆 tpm。已存在的旧文件会自动备份成 `*.bak.<时间戳>`。

> 用拷贝而非软链:这些配置很少改动,直接拷贝更简单、不易乱套。在 repo 里改完后,
> **重跑 `bash terminal/install.sh`** 即可应用。

## 装完之后

1. **Ghostty**:重开,或窗口内按 `Cmd+Shift+,` 重载。
2. **tmux**:启动 `tmux` → 按 `Ctrl+b` 然后 `I`(大写)安装插件。
3. **验证持久化**:`Ctrl+b` 然后 `Ctrl-s` 手动存一次;重启 tmux 应自动恢复布局与各窗格目录。

## 背景知识:Ghostty 与 tmux 的概念分层

最容易混淆的点:**Ghostty 和 tmux 各有自己的 "window",但完全是两回事**。
一句话类比:**Ghostty 是显示器,tmux 是主机**。拔掉显示器(quit Ghostty),
主机里的东西(session)照样跑;重新接上(`gtmux restore`)画面就回来了。

**上层 —— Ghostty,负责"显示"(GUI 程序,Cmd+Q 就没了):**

```text
┌─ Ghostty window(macOS 窗口,Cmd+N)──────────────┐
│  tab 栏(Cmd+T):   [ blog ]   [ shop ]           │
│ ┌─────────────────────────────────────────────────┐
│ │                                                 │
│ │   当前 tab 的内容区 = 它 attach 的那个          │
│ │   tmux session 正在显示的画面                   │
│ │                                                 │
│ └─────────────────────────────────────────────────┘
└──────────────────────────────────────────────────┘
        │ tab[blog] attach          │ tab[shop] attach
        ▼                           ▼
```

**下层 —— tmux,负责"状态"(后台进程,quit Ghostty 也不死):**

```text
tmux server(整台机器只有一个,装着所有状态)
├── session "blog"                ← ≈ 一个项目的工作区
│   ├── window 0 "code"           ← ≈ 项目里的一个任务(显示在底部状态栏)
│   │   ├── pane: claude          ← window 内的分屏格子
│   │   └── pane: vim
│   └── window 1 "logs"
│       └── pane: tail -f
└── session "shop"                ← 另一个项目,被 tab[shop] attach
    └── window 0 "dev"
```

五个概念对照:

| 概念 | 属于 | 类比 | 怎么创建 |
|------|------|------|----------|
| window | Ghostty | 一台显示器 | `Cmd+N` |
| tab | Ghostty | 显示器上的一个"频道",通常对着一个 session | `Cmd+T` |
| session | tmux | 一个项目的整个工作区 | `tmux new -s 名字` |
| window | tmux | 项目里的一个任务页签(底部状态栏可见) | `前缀+c` |
| pane | tmux | 任务画面里的分屏格子 | `前缀+\|` / `前缀+-` |

生命周期一句话:关 tab 或 quit Ghostty,**只是断开显示**,session 在后台照跑,
`gtmux restore` 随时接回;重启电脑连 server 也没了,但 continuum 每 5 分钟的
存档能恢复布局(见下文)。概念详解见 `docs/02-tmux-concepts.zh.md`。

推论:**命名也要写在状态层**。Ghostty tab 标题已配置为自动显示
"session 名 — window 名"(tmux `set-titles`),接回后名字自动正确;
不要手动给 Ghostty tab 改名(会被覆盖,且 quit 后必丢),
要改名就改 session(`tmux rename-session`)或 window(`前缀+,`)。
这个"名字写在 tab 上"的绑定,也正是 `gtmux focus <session>` 能直接跳到对应
tab 的原因 —— 写的一侧(`set-titles`)和读的一侧(`focus`)是同一套能力。

## `gtmux` 命令行 —— tmux 会话与 coding agent 的指挥台

`gtmux` 是你 tmux 会话、以及里面跑着的 coding agent 的指挥台 —— **`agents`**(谁在跑 /
空闲 / 等你)、**`overview`**(看会话)、**`restore`**(重建 tab)、**`focus`**(跳到
tab/pane)。它不是 spawner:是覆盖你已经在 tmux 里跑的一切的"雷达 + 遥控器"。

它维护在**独立仓库 —— [github.com/chenchaoyi/gtmux](https://github.com/chenchaoyi/gtmux)**,
完整 CLI 文档都在那边。`install.sh`(第 3 步)用它的 curl 一行命令替你安装(预编译、经
校验和验证的二进制;优先 GitHub,失败回退国内镜像,无需 Go 工具链):

```sh
curl -fsSL https://raw.githubusercontent.com/chenchaoyi/gtmux/main/install.sh | bash
```

### 本工作环境怎么把它接进来

gtmux 只是个 CLI;下面这些键绑定在本仓库的 `tmux/tmux.conf` 里(还有
`set-titles-string '#S — #W'`,`focus` 靠它定位 tab):

| 键 | 跑 | 作用 |
| --- | --- | --- |
| `前缀 + g` | `gtmux overview --popup` | session/window/pane 弹窗,悬浮在任何全屏程序之上 |
| `前缀 + a` | `gtmux agents --watch --popup` | 实时 agent 面板(↑/↓ 选 · Enter 跳 · q 退;跳转后自动关) |
| `前缀 + G` | 速查表 | tmux 命令速查表(`~/.tmux-cheatsheet.txt`) |
| `前缀 + J` | `gtmux focus $(cat …/last-finished)` | 跳到最近完成的那个 agent 的 pane |

Ghostty 重启后,在任意 tab 里跑一次 **`gtmux restore`**,把每个 tmux session 接回到各自
的 tab(电脑重启后它还会启动 tmux 并等 tmux-continuum —— 在 `tmux.conf` 里配置 —— 恢复
最近一次存档)。`⏸ 等输入` / `✓ latest` 这些 agent 信号、以及点击直达的通知,都由本仓库的
`claude-notify` 钩子产出(见下一节)。

完整的逐命令文档(agent 检测与 `agents.json`、restore 各模式、`--json`、镜像选项等)见
[gtmux 仓库 README](https://github.com/chenchaoyi/gtmux/blob/main/README.zh.md)。

## agent 完成通知,点击直达"确切 pane"(Claude Code)

不用 tmux 时,Claude Code 的 agent 跑完,Ghostty 会弹原生通知,点一下就跳到那个
tab。**在 tmux 下这条路是断的** —— tmux 会丢掉那条裸通知转义序列。`claude-notify`
(由 `install.sh` 安装的 Claude Code 钩子)把它补回来,而且**落到 agent 当时所在的
那个确切 pane**,**用不用 peon-ping 都行**:

- **任意** tmux session 里 agent 完成都会弹桌面通知 —— 包括你没在看的那些 ——
  并且**你正盯着该 session 的 Ghostty tab 时保持安静**。
- **点击通知 → 直接跳到那个确切 pane**:在 tmux 里选中它的 window+pane,再把
  Ghostty tab 切前台。
- **`-activate` 诀窍**:新版 macOS(26.x)上通知点击只能"激活某个 app",点击跑命令
  (`-execute`)已静默失效。所以点击去 `-activate` 一个极小的中转 app
  **`GtmuxFocus.app`**(两个文件,由 `install.sh` 生成并注册到 Launch Services),它读
  `~/.local/share/gtmux/last-finished` 里记录的 pane id,跑 `gtmux focus <pane>`。
  首次点击会弹「GtmuxFocus 想要控制 Ghostty」—— 允许一次即可。
- **`前缀 + J`** 用键盘做同样的跳转(你本来就在 Ghostty 里时更顺手,不用碰通知)。
- 通知器是 **`terminal-notifier`**(安装器默认帮你 `brew install`,回车即装)。没装也有
  可靠的原生通知,只是不可点。
- 自包含 —— 不依赖任何插件。检测到 peon-ping 时,安装器会**提示你关掉 peon 自己的
  桌面通知(和 `terminal_tab_title`)**,免得双弹或跟 `set-titles` 抢标题。

它是 **opt-in**:`install.sh` 最后一步会先问你再启用,因为接线要改
`~/.claude/settings.json`(有备份、幂等、保留你已有的钩子)。想开随时重跑安装器。

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
| tab 命名 | 名字起在 tmux 的 session/window 上,**`set-titles` 自动映射到 Ghostty tab 标题** | 名字活在状态层 —— quit/重启不丢,`gtmux restore` 接回后自动正确,零手动命名 |
| 工作区命令行 | **一个 `gtmux`**(Go):`overview` · `agents` · `restore` · `focus` | 一个命令管整个工作区 + 多 agent 状态;`--lang=en|zh` |
| 现在跑着什么? | **前缀+g** session 概览弹窗(shell 里也可 `gtmux overview`) | 一眼看清 session/window/pane 数量与明细 |
| agent 完成提醒 | **`claude-notify`** 钩子:完成弹通知,**点击→ 确切 pane**(靠 `GtmuxFocus.app` + `-activate`);也可 `前缀+J` | 补回 tmux 下被掐断的"点击直达"通知,精确落到 agent 所在 pane;在看时不打扰;不依赖 peon |
| 忘了按键? | **前缀+G** 速查表弹窗;前缀+? 全量键位;前缀+/ 再按某键=解释它 | 不离开 tmux 随手查 |
| 并行 agent | 一项目一 session,任务分 window | 见 docs/04 |

详细取舍与背景见 `docs/`。
