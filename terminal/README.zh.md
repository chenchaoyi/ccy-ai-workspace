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
│   └── tmux.conf        tmux 配置(保留默认 Ctrl+b 前缀)
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
# 前置:已装好 Ghostty 和 tmux
#   brew install --cask ghostty ; brew install tmux
git clone git@github.com:chenchaoyi/ccy-ai-workspace.git
cd ccy-ai-workspace
bash terminal/install.sh
```

脚本会**拷贝**配置到:
- `~/.config/ghostty/config`
- `~/.tmux.conf`

并克隆 tpm。已存在的旧文件会自动备份成 `*.bak.<时间戳>`。

> 用拷贝而非软链:这些配置很少改动,直接拷贝更简单、不易乱套。在 repo 里改完后,
> **重跑 `bash terminal/install.sh`** 即可应用。

## 装完之后

1. **Ghostty**:重开,或窗口内按 `Cmd+Shift+,` 重载。
2. **tmux**:启动 `tmux` → 按 `Ctrl+b` 然后 `I`(大写)安装插件。
3. **验证持久化**:`Ctrl+b` 然后 `Ctrl-s` 手动存一次;重启 tmux 应自动恢复布局与各窗格目录。

## 核心选择速记

| 项 | 选择 | 为什么 |
|----|------|--------|
| 终端 | Ghostty | GPU 渲染、省内存、原生分屏 |
| 前缀键 | **保留 Ctrl+b** | 不折腾肌肉记忆 |
| pane 切换 | **vi 风格 h/j/k/l**(方向键也可) | 习惯 vim 手感 |
| 持久化 | tmux + resurrect + continuum | 跨重启恢复 session/window/cwd,比快照工具更彻底 |
| 并行 agent | 一项目一 session,任务分 window | 见 docs/04 |

详细取舍与背景见 `docs/`。
