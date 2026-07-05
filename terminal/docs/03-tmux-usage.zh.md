# tmux 日常工作流与常用命令

> English: [03-tmux-usage.en.md](./03-tmux-usage.en.md)
> 前缀键为默认 `Ctrl+b`；下文 `前缀 + x` = 先按 `Ctrl+b` 松开再按 `x`。

## 心智模型：一项目一 session

```bash
tmux new -s saas        # 为项目 saas 新建并进入 session
# 在里面开几个 window 分管任务，见下
tmux new -s bike        # 另一个项目，另起一套
```

推荐每个项目的 window 布局：

```
session: saas
  ├─ window 0: claude   主 Claude Code 会话
  ├─ window 1: dev      dev server（pnpm dev），让 agent 能读它日志
  └─ window 2: git      看 diff / 提交
```

## 最常用命令

### Session
| 操作 | 命令 |
|------|------|
| 新建并命名 | `tmux new -s 名字` |
| 列出所有 | `tmux ls` |
| 重新接入 | `tmux attach -t 名字` |
| 脱离（后台继续跑） | `前缀 + d` |
| 杀掉 | `tmux kill-session -t 名字` |

### Window（标签）
| 操作 | 键 |
|------|----|
| 新建（留在当前目录） | `前缀 + c` |
| 下一个 / 上一个 | `前缀 + n` / `前缀 + p` |
| 跳到第 N 个 | `前缀 + 数字` |
| 列表选择 | `前缀 + w` |
| 重命名 | `前缀 + ,` |
| 关闭 | `前缀 + &` |

> **窗口命名（本配置已优化）**：默认 tmux 会把窗口名改成当前程序（全是 `bash`，没用）。
> 本配置改成：**未命名的窗口显示所在目录名**（如 `saas`），**手动 `前缀 + ,` 命名后会保留**
> （如 `claude`/`dev`/`git`），程序也无法偷偷改名。后台窗口有新输出时状态栏会显示一个 `•`，
> 方便发现哪个 agent 跑完了。建议每个窗口按角色命名。`前缀 + w` 打开带预览的窗口树。

### Pane（分屏）
| 操作 | 键 |
|------|----|
| 左右分屏（留在当前目录） | `前缀 + |` |
| 上下分屏（留在当前目录） | `前缀 + -` |
| 在 pane 间切换 | `前缀 + h/j/k/l`（方向键也可） |
| 改大小 | `前缀 + 按住方向键` 或鼠标拖拽 |
| 放大/还原当前 pane | `前缀 + z` |
| 关闭 | `前缀 + x` 或 `exit` |

### 复制 / 翻历史（vi 键位）
- 进入复制模式：`前缀 + [`
- 翻页 `Ctrl-u`/`Ctrl-d`，逐行 `j`/`k`，搜索 `/`，选区 `v`，复制 `y`，退出 `q`
- 鼠标也可直接滚轮翻、拖拽选

### 打开 URL 链接（Ghostty + tmux）
- **`Cmd + Shift + 点击`** 链接即可在浏览器打开。
- 为什么要加 `Shift`：开了 `mouse on` 后，tmux 会抢走鼠标点击。按住 `Shift` 可绕过
  tmux 的鼠标捕获（Ghostty 的 `mouse-shift-capture` 默认行为），把点击交还给 Ghostty；
  `Cmd` 是 Ghostty 在 macOS 上「打开链接」的修饰键。先按住 `Cmd` 悬停可看到链接下划线高亮。
- 不在 tmux 里时（纯 Ghostty），单按 `Cmd + 点击` 即可。多按 `Shift` 只是因为 tmux 抢了鼠标。

### 其它
- 重载配置：`前缀 + r`（本配置自定义）
- 手动存档：`前缀 + Ctrl-s`；恢复：`前缀 + Ctrl-r`

## 持久化：跨重启恢复

本配置装了 **tmux-resurrect + tmux-continuum**：
- continuum 每 ~15 分钟自动存档，且 **tmux 启动时自动恢复**上次的 session/window/pane 布局与**各 pane 的 cwd**。
- resurrect 负责实际的存/恢复（已开 `@resurrect-capture-pane-contents on`，连 pane 内容一起存）。

插件由 `gtmux doctor --fix`（`install.sh` 的一部分）装好，无需 `前缀 + I`。重启电脑、关掉 tmux，再开 `tmux` 就回来了。

> 这正是当初 Ghostty 丢 cwd 痛点的彻底解法：session 活在后台进程里，目录和运行中的进程都不死；
> 即使重启，continuum 也能把布局与目录拉回来。

## 与 Claude Code 配合的小贴士
- dev server 放独立 window，agent 可用 `tmux capture-pane -t dev -p` 读它输出来判断状态。
- Claude Code 懂 tmux：可让它读某个 pane、给某个 pane 发命令。
- Shift+Enter 换行已通过 `extended-keys` + Ghostty 的 keybind 打通。
