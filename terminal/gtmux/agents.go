package main

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"
)

// Claude Code's foreground process reports its command as its version (e.g.
// "2.1.177"), which is how we identify a Claude pane that is actively working
// (its title is "<spinner> <task>" then, with no "Claude Code" text).
var claudeVersionRe = regexp.MustCompile(`^\d+\.\d+\.\d+`)

// agentProfile identifies a coding agent and (optionally) its idle marker.
// Working state is detected generically from a braille-spinner title glyph
// (most agent TUIs animate one), so profiles mainly map command/name → label.
type agentProfile struct {
	Name      string   `json:"name"`                // display label, e.g. "Claude Code"
	Commands  []string `json:"commands"`            // pane_current_command matches
	IdleGlyph string   `json:"idleGlyph,omitempty"` // leading rune meaning idle (e.g. "✳")
}

// Built-in profiles. Extend or override via ~/.config/gtmux/agents.json
// (a JSON array of {name, commands, idleGlyph}); user entries take precedence.
var builtinProfiles = []agentProfile{
	{Name: "Claude Code", Commands: []string{"claude"}, IdleGlyph: "✳"},
	{Name: "Codex", Commands: []string{"codex"}},
	{Name: "Gemini", Commands: []string{"gemini"}},
	{Name: "Aider", Commands: []string{"aider"}},
	{Name: "opencode", Commands: []string{"opencode"}},
	{Name: "Crush", Commands: []string{"crush"}},
	{Name: "Cursor", Commands: []string{"cursor-agent", "cursor"}},
	{Name: "Amp", Commands: []string{"amp"}},
}

func loadProfiles() []agentProfile {
	profiles := builtinProfiles
	path := os.Getenv("HOME") + "/.config/gtmux/agents.json"
	if b, err := os.ReadFile(path); err == nil {
		var user []agentProfile
		if json.Unmarshal(b, &user) == nil && len(user) > 0 {
			profiles = append(user, profiles...) // user entries win
		}
	}
	return profiles
}

type agentPane struct {
	paneID   string
	loc      string // session:window.pane
	agent    string // display name, "" if unknown type
	task     string // title with the status glyph stripped
	status   string // "working" | "idle" | "running"
	activity bool
}

// isBrailleSpinner reports whether r is in the braille block (U+2800–U+28FF),
// the de-facto spinner glyph most agent TUIs animate while working.
func isBrailleSpinner(r rune) bool { return r >= 0x2800 && r <= 0x28FF }

// classifyAgent decides whether a pane runs a coding agent, which one, and its
// status. Order: command match (most reliable) → title-name match (catches
// agents whose command is a version string, like Claude Code) → glyph only.
func classifyAgent(title, cmd string, profiles []agentProfile) (isAgent bool, agent, status, task string) {
	t := strings.TrimSpace(title)
	rs := []rune(t)

	// Agent name by command, then by name appearing in the title.
	for _, p := range profiles {
		for _, c := range p.Commands {
			if cmd == c {
				agent = p.Name
			}
		}
		if agent != "" {
			break
		}
	}
	if agent == "" {
		for i := range profiles {
			if strings.Contains(t, profiles[i].Name) {
				agent = profiles[i].Name
				break
			}
		}
	}
	if agent == "" && claudeVersionRe.MatchString(cmd) {
		agent = "Claude Code" // working Claude pane (command is its version string)
	}

	// Status from the leading title glyph.
	hasGlyph := false
	if len(rs) > 0 {
		switch {
		case isBrailleSpinner(rs[0]):
			status, hasGlyph = "working", true
		case rs[0] == 0x2733: // ✳ → idle/ready (Claude Code's marker)
			status, hasGlyph = "idle", true
			if agent == "" {
				agent = "Claude Code"
			}
		default:
			// match a profile's custom idle glyph
			for _, p := range profiles {
				if p.IdleGlyph != "" && strings.HasPrefix(t, p.IdleGlyph) {
					status, hasGlyph = "idle", true
					if agent == "" {
						agent = p.Name
					}
				}
			}
		}
	}

	if status == "" && agent != "" {
		status = "running" // command-detected agent, no title state signal
	}
	if status != "" && agent == "" {
		agent = tr("agent", "agent") // working spinner but unknown type
	}

	isAgent = agent != "" || status != ""
	if !isAgent {
		return false, "", "", ""
	}
	task = t
	if hasGlyph && len(rs) > 1 {
		task = strings.TrimSpace(string(rs[1:]))
	}
	if task == agent { // title is just the placeholder name, not a real task
		task = ""
	}
	return true, agent, status, task
}

// cmdAgents implements `gtmux agents` — coding agents across all tmux panes.
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
	profiles := loadProfiles()

	lastFinished := ""
	if b, err := os.ReadFile(os.Getenv("HOME") + "/.local/share/gtmux/last-finished"); err == nil {
		lastFinished = strings.TrimSpace(string(b))
	}

	fields := "#{pane_id}\t#{session_name}\t#{window_index}\t#{pane_index}\t" +
		"#{pane_title}\t#{pane_current_command}\t#{window_activity_flag}"
	var panes []agentPane
	nWorking := 0
	for _, line := range tmuxLines("list-panes", "-a", "-F", fields) {
		f := strings.SplitN(line, "\t", 7)
		if len(f) < 7 {
			continue
		}
		isAgent, agent, status, task := classifyAgent(f[4], f[5], profiles)
		if !isAgent {
			continue
		}
		if status == "working" {
			nWorking++
		}
		panes = append(panes, agentPane{
			paneID:   f[0],
			loc:      fmt.Sprintf("%s:%s.%s", f[1], f[2], f[3]),
			agent:    agent,
			task:     task,
			status:   status,
			activity: f[6] == "1",
		})
	}

	// Working agents first (most relevant), then by location for stability.
	sort.SliceStable(panes, func(i, j int) bool {
		wi, wj := panes[i].status == "working", panes[j].status == "working"
		if wi != wj {
			return wi
		}
		return panes[i].loc < panes[j].loc
	})

	// Header with a status breakdown.
	head := tr("agents", "agent")
	summary := pl(len(panes), "agent")
	if len(panes) > 0 {
		summary += tr(
			fmt.Sprintf(" · %d working · %d idle", nWorking, len(panes)-nWorking),
			fmt.Sprintf(" · %d 运行中 · %d 空闲", nWorking, len(panes)-nWorking))
	}
	fmt.Printf("%sgtmux %s%s — %s\n\n", cBold, head, cReset, summary)
	if len(panes) == 0 {
		say("No coding-agent panes found.", "没有发现 coding-agent 的 pane。")
		return 0
	}

	noTask := tr("—", "—")
	for _, p := range panes {
		glyph, color, label := statusStyle(p.status)
		task := p.task
		if task == "" {
			task = cDim + noTask + cReset
		}
		dot := ""
		if p.activity {
			dot = cYellow + " •" + cReset
		}
		done := ""
		if p.paneID == lastFinished && p.status != "working" {
			done = cYellow + tr("  ✓ latest", "  ✓ 最近完成") + cReset
		}
		fmt.Printf("%s%s%s %s%s%s %s%s%s %s%s%s %s%s%s%s\n",
			color, glyph, cReset,
			color, padRight(label, 8), cReset,
			cBold, padRight(p.agent, 12), cReset,
			cBold, padRight(p.loc, 22), cReset,
			task, dot, cDim+" "+p.paneID+cReset, done)
	}

	fmt.Printf("\n%s%s%s\n", cDim,
		tr("jump: gtmux focus <pane>   (e.g. gtmux focus "+panes[0].paneID+")",
			"跳转: gtmux focus <pane>   (例如 gtmux focus "+panes[0].paneID+")"), cReset)
	return 0
}

func statusStyle(status string) (glyph, color, label string) {
	switch status {
	case "working":
		return "⠿", cCyan, tr("working", "运行中")
	case "idle":
		return "✳", cGreen, tr("idle", "空闲")
	default:
		return "●", cYellow, tr("running", "运行中")
	}
}
