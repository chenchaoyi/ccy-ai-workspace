package main

import "fmt"

const usageEN = `gtmux — drive your Ghostty <-> tmux workspace from the tmux state layer.

Usage:
  gtmux [--lang=en|zh] <command> [options]

Commands:
  overview [--popup]      sessions / windows / panes summary (default if no command)
                          --popup is what prefix+g opens
  agents                  coding agents across your panes: working / idle, where,
                          and the pane id to jump to
  restore                 one Ghostty tab per session, attach all
    restore --pick|-p     list & choose (numbers / Enter=all / q=cancel)
    restore <name>        attach that session by name in THIS tab
    restore --one         attach the next unattached session in THIS tab
    restore --dry-run     print what would happen, change nothing
  focus <name|pane-id>    jump to that session's Ghostty tab; a tmux pane id
                          (%N) lands on that exact window+pane
  -h, --help              show this help

Options:
  --lang=en|zh   output language (default en; or set GTMUX_LANG)

Notes:
  - focus reads tmux set-titles ('#S — #W') tab titles; keep set-titles on.
  - restore/focus drive Ghostty via AppleScript: the first run asks for
    Automation permission ("wants to control Ghostty") — allow it.
  - After a reboot, restore starts tmux and waits for tmux-continuum to restore
    the last autosave (layout/dirs/screen text — not running programs).
`

const usageZH = `gtmux —— 用 tmux 状态层驱动 Ghostty ↔ tmux 工作区。

用法:
  gtmux [--lang=en|zh] <命令> [选项]

命令:
  overview [--popup]      session / window / pane 汇总(不带命令时的默认)
                          --popup 就是 prefix+g 弹的那个弹窗
  agents                  列出各 pane 里的 coding agent:运行中 / 空闲、在哪、
                          以及可跳转的 pane id
  restore                 每个 session 一个 Ghostty tab,全部接回
    restore --pick|-p     列出来选(编号 / 回车=全部 / q=取消)
    restore <名字>         按名字把当前 tab 接回指定 session
    restore --one         只把当前 tab 接回下一个无人连接的 session
    restore --dry-run     只打印将要做什么,不实际执行
  focus <名字|pane-id>    跳到该 session 的 Ghostty tab;给 tmux pane id(%N)
                          则精确落到那个 window+pane
  -h, --help              显示本帮助

选项:
  --lang=en|zh   输出语言(默认 en;也可用 GTMUX_LANG 环境变量设默认)

说明:
  - focus 读 tmux set-titles('#S — #W')写在 tab 标题上的名字,请保持 set-titles 开启。
  - restore/focus 通过 AppleScript 控制 Ghostty:首次运行会弹自动化授权
    (「想要控制 Ghostty」)—— 点允许。
  - 电脑重启后,restore 会启动 tmux 并等 tmux-continuum 恢复最近一次自动存档
    (布局/目录/屏幕文本 —— 不含正在运行的程序)。
`

func usage() {
	if lang == "zh" {
		fmt.Print(usageZH)
	} else {
		fmt.Print(usageEN)
	}
}
