package main

import (
	"fmt"
	"os"
	"strings"
)

// Coding agents detected by foreground process name (non-Claude agents).
// Claude Code is detected by its pane title glyph instead (see classifyAgent).
var agentCommands = map[string]bool{
	"claude": true, "codex": true, "gemini": true, "aider": true,
	"cursor-agent": true, "opencode": true, "crush": true,
}

type agentPane struct {
	paneID   string
	loc      string // session:window.pane
	session  string
	title    string // task description (glyph stripped)
	status   string // "working" | "idle" | "running"
	activity bool   // unseen output since last viewed
}

// classifyAgent decides whether a pane is a coding-agent pane and its status.
// Claude Code sets its pane title to "<glyph> <task>": a braille spinner glyph
// (U+2800–U+28FF) means actively working; "✳" (U+2733) means idle/ready.
// Other agents are matched by their foreground command name.
func classifyAgent(title, cmd string) (isAgent bool, status, task string) {
	rs := []rune(strings.TrimSpace(title))
	if len(rs) > 0 {
		switch {
		case rs[0] >= 0x2800 && rs[0] <= 0x28FF: // braille spinner frame → working
			return true, "working", strings.TrimSpace(string(rs[1:]))
		case rs[0] == 0x2733: // ✳ → idle/ready
			return true, "idle", strings.TrimSpace(string(rs[1:]))
		}
	}
	if strings.Contains(title, "Claude Code") {
		return true, "idle", title
	}
	if agentCommands[cmd] {
		return true, "running", title
	}
	return false, "", ""
}

// cmdAgents implements `gtmux agents` — coding agents across all tmux panes,
// with their working/idle status, location, and the pane id to jump to.
func cmdAgents(args []string) int {
	for _, a := range args {
		if a == "-h" || a == "--help" {
			usage()
			return 0
		}
	}
	if !tmuxServerUp() {
		say("No tmux server running", "没有运行中的 tmux server")
		return 1
	}

	lastFinished := ""
	if b, err := os.ReadFile(os.Getenv("HOME") + "/.local/share/gtmux/last-finished"); err == nil {
		lastFinished = strings.TrimSpace(string(b))
	}

	fields := "#{pane_id}\t#{session_name}\t#{window_index}\t#{pane_index}\t" +
		"#{pane_title}\t#{pane_current_command}\t#{window_activity_flag}"
	var panes []agentPane
	for _, line := range tmuxLines("list-panes", "-a", "-F", fields) {
		f := strings.SplitN(line, "\t", 7)
		if len(f) < 7 {
			continue
		}
		isAgent, status, task := classifyAgent(f[4], f[5])
		if !isAgent {
			continue
		}
		if task == "" {
			task = tr("(no task title)", "(无任务标题)")
		}
		panes = append(panes, agentPane{
			paneID:   f[0],
			loc:      fmt.Sprintf("%s:%s.%s", f[1], f[2], f[3]),
			session:  f[1],
			title:    task,
			status:   status,
			activity: f[6] == "1",
		})
	}

	header := tr("agents", "agent")
	fmt.Printf("%sgtmux %s%s — %s\n\n", cBold, header, cReset, pl(len(panes), "agent"))
	if len(panes) == 0 {
		say("No coding-agent panes found.", "没有发现 coding-agent 的 pane。")
		return 0
	}

	for _, p := range panes {
		glyph, color, label := statusStyle(p.status)
		dot := "  "
		if p.activity {
			dot = " •" // unseen output
		}
		done := ""
		if p.paneID == lastFinished && p.status != "working" {
			done = cYellow + tr("  ✓ latest", "  ✓ 最近完成") + cReset
		}
		fmt.Printf("%s%s%s %s%s%s %s%s%s %s%s%s%s\n",
			color, glyph, cReset,
			color, padRight(label, 8), cReset,
			cBold, padRight(p.loc, 22), cReset,
			p.title, dot, cDim+" "+p.paneID+cReset, done)
	}

	fmt.Printf("\n%s%s%s\n", cDim,
		tr("jump: gtmux focus <pane>   (e.g. gtmux focus "+firstPaneID(panes)+")",
			"跳转: gtmux focus <pane>   (例如 gtmux focus "+firstPaneID(panes)+")"), cReset)
	return 0
}

func statusStyle(status string) (glyph, color, label string) {
	switch status {
	case "working":
		return "⠿", cCyan, tr("working", "运行中")
	case "idle":
		return "✳", cGreen, tr("idle", "空闲")
	default:
		return "●", cGreen, tr("running", "运行中")
	}
}

func firstPaneID(panes []agentPane) string {
	if len(panes) > 0 {
		return panes[0].paneID
	}
	return "%0"
}
