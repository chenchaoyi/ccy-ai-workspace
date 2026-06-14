package main

import (
	"os"
	"strings"
)

// selfPath is the absolute path to this binary (for popup re-exec).
func selfPath() string {
	if p, err := os.Executable(); err == nil && p != "" {
		return p
	}
	return "gtmux"
}

func main() {
	// Default language from env; a global --lang=en|zh flag overrides it.
	if l := os.Getenv("GTMUX_LANG"); l == "zh" || l == "en" {
		lang = l
	}
	var args []string
	for _, a := range os.Args[1:] {
		switch {
		case a == "--lang=zh":
			lang = "zh"
		case a == "--lang=en":
			lang = "en"
		case strings.HasPrefix(a, "--lang="):
			sae("gtmux: unknown --lang value (use en|zh)", "gtmux: 无效的 --lang(可用 en|zh)")
			os.Exit(2)
		default:
			args = append(args, a)
		}
	}

	sub := "overview"
	if len(args) > 0 {
		sub = args[0]
		args = args[1:]
	}

	code := 0
	switch sub {
	case "overview", "ov":
		code = cmdOverview(args)
	case "restore", "re":
		code = cmdRestore(args)
	case "focus", "fo":
		code = cmdFocus(args)
	case "agents", "ag":
		code = cmdAgents(args)
	case "-h", "--help", "help":
		usage()
	default:
		sae("gtmux: unknown command '"+sub+"' (try: overview | restore | focus | agents | --help)",
			"gtmux: 未知命令 '"+sub+"'(可用:overview | restore | focus | agents | --help)")
		code = 2
	}
	os.Exit(code)
}
