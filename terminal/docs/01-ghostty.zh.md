# Ghostty 配置说明与调校结论

> English: [01-ghostty.en.md](./01-ghostty.en.md)

## 这份配置在做什么

复刻 Warp "phenomenon" 的暗色手感(Hack 15pt、近黑背景、暖白前景、periwinkle 光标),
并加了一批对 coding agent 友好的设定(响铃提醒、命令提示符跳转、长回滚缓冲等)。

## 对比度 / "晃眼"问题的结论 ⭐

**现象**:最初配置是纯白前景 `#fffefb` + 近黑背景 `#111111`,文字看久了发晃、刺眼。

**原因**:三点叠加。

| 配置 | 原值 | 问题 |
|------|------|------|
| `foreground` | `#fffefb` 近纯白 | 白配近黑,对比度 ~17:1(WCAG AAA 只要 7:1),高亮像素"光晕外溢"(halation) |
| `background` | `#111111` 近纯黑 | 背景越黑,白字边缘光晕越明显 |
| `font-thicken` | `true` | 给字形加了伪描边,白字更"重"更刺眼 |

**调校**:

| 配置 | 新值 | 效果 |
|------|------|------|
| `foreground` | `#d4d2cc` 暖灰白 | 对比度降到 ~10:1,清晰但不刺眼 |
| `background` | `#17171a` | 背景抬高一档并带一点冷调,削弱光晕 |
| `font-thicken` | `false` | 去掉伪加粗,笔画回归正常 |

**还想微调**:嫌亮→ `foreground` 再降到 `c8c6c0`/`bdbbb5`;嫌发灰→ 回到 `e0ded8`。

## 关于"退出后工作目录丢失"的结论

**现象**:`Cmd+Q` 退出再开,窗口位置还在,但每个标签/分屏的目录都回到了用户根目录。

**根因**:`window-save-state = always` 在 macOS 上只保证恢复**窗口几何**;恢复**每个 surface 的 cwd**
属于"富状态",依赖两件事:① shell integration 上报目录(已开,`shell-integration = detect`);
② macOS 系统级状态恢复通道,由 **"系统设置 → 桌面与程序坞 → 退出应用程序时关闭窗口"** 控制。
该勾默认打开 → 退出时丢弃富状态 → 只剩几何能恢复。

**两条出路**(详见 `04` 与下面):
1. **打开系统恢复**:`defaults write -g NSQuitAlwaysKeepsWindows -bool true`(或取消那个勾)。全局生效、尽力而为。
2. **改用 tmux**(本仓库选择):session 活在后台进程里,目录/布局/运行进程都不死,配 resurrect/continuum 还能跨重启。比原生恢复彻底。

> 同类的快照工具还调研过:**gtab**(轻量、命名工作区)、**crex/cmux-resurrect**(守护进程自动快照、可恢复运行进程)、**ghostty-workspace**(声明式 YAML)。结论是:重度使用直接上 tmux,见 `04`。

## 加载路径的坑

Ghostty 默认读名为 `config`(无扩展名)的文件,位置:
- `~/.config/ghostty/config`(XDG,跨平台首选)
- `~/Library/Application Support/com.mitchellh.ghostty/config`(macOS)

本机历史上活配置叫 `config.ghostty`(非标准名,但确被加载)。迁移时 `install.sh` 会拷贝到标准的
`~/.config/ghostty/config`,并把旧的 `config.ghostty` 备份掉,避免重复加载。
验证有效配置:`/Applications/Ghostty.app/Contents/MacOS/ghostty +show-config | grep foreground`。
