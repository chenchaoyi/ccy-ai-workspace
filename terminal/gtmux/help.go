package main

import "fmt"

const usageEN = `Usage:
  gtmux [--lang=en|zh] <command> [options]
  gtmux                    (no command) prints this help

Commands:
  overview [--popup]      sessions / windows / panes summary
                          --popup is what prefix+g opens
  agents [--watch]        coding agents across your panes: waiting / working /
                          idle, where, and the pane id to jump to. --watch is a
                          live dashboard (↑/↓ select · enter jump · r · q)
  restore                 one Ghostty tab per session, attach all
    restore --pick|-p     list & choose (numbers / Enter=all / q=cancel)
    restore <name>        attach that session by name in THIS tab
    restore --one         attach the next unattached session in THIS tab
    restore --dry-run     print what would happen, change nothing
  focus <name|pane-id>    jump to that session's Ghostty tab; a tmux pane id
                          (%N) lands on that exact window+pane
  -h, --help              show this help
  -v, --version           print the version

Options:
  --lang=en|zh   output language (default en; or set GTMUX_LANG)

Notes:
  - "agents" reads each agent's pane title; ⏸ waiting (blocked on you) comes from
    Claude Code's Notification hook via claude-notify, and sorts to the top.
  - restore/focus drive Ghostty (1.3+) via AppleScript: the first run asks for
    Automation permission ("wants to control Ghostty") — allow it.
  - After a reboot, restore starts tmux and waits for tmux-continuum to restore
    the last autosave (layout/dirs/screen text — not running programs).
`

const usageZH = `用法:
  gtmux [--lang=en|zh] <命令> [选项]
  gtmux                    (不带命令)显示本帮助

命令:
  overview [--popup]      session / window / pane 汇总
                          --popup 就是 prefix+g 弹的那个弹窗
  agents [--watch]        各 pane 里的 coding agent:等输入 / 运行中 / 空闲、
                          在哪、以及可跳转的 pane id。--watch 是实时面板
                          (↑/↓ 选择 · enter 跳转 · r 刷新 · q 退出)
  restore                 每个 session 一个 Ghostty tab,全部接回
    restore --pick|-p     列出来选(编号 / 回车=全部 / q=取消)
    restore <名字>         按名字把当前 tab 接回指定 session
    restore --one         只把当前 tab 接回下一个无人连接的 session
    restore --dry-run     只打印将要做什么,不实际执行
  focus <名字|pane-id>    跳到该 session 的 Ghostty tab;给 tmux pane id(%N)
                          则精确落到那个 window+pane
  -h, --help              显示本帮助
  -v, --version           打印版本号

选项:
  --lang=en|zh   输出语言(默认 en;也可用 GTMUX_LANG 环境变量设默认)

说明:
  - "agents" 读各 agent 的 pane 标题;⏸ 等输入(卡在等你)来自 Claude Code 的
    Notification 钩子(经 claude-notify),会排到最前。
  - restore/focus 通过 AppleScript 控制 Ghostty(1.3+):首次运行会弹自动化授权
    (「想要控制 Ghostty」)—— 点允许。
  - 电脑重启后,restore 会启动 tmux 并等 tmux-continuum 恢复最近一次自动存档
    (布局/目录/屏幕文本 —— 不含正在运行的程序)。
`

func usage() {
	fmt.Printf("gtmux %s — %s\n\n", version, tagline())
	if lang == "zh" {
		fmt.Print(usageZH)
	} else {
		fmt.Print(usageEN)
	}
}
