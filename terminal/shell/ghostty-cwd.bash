# ============================================================================
# ghostty-cwd.bash — report the shell's cwd to Ghostty (OSC 7), bash 3.2 OK
# ghostty-cwd.bash —— 向 Ghostty 上报当前目录(OSC 7),兼容 bash 3.2
#
# Why: "new window/tab inherits working directory" needs the shell to REPORT
#   its cwd. Ghostty auto-injects this for zsh/fish, but macOS's /bin/bash
#   (3.2) is excluded — even Ghostty's own ghostty.bash gates its hooks behind
#   bash >= 4.4. Without a report, every new window starts at $HOME.
# 背景: "新窗口/新 tab 继承工作目录"的前提是 shell 主动【上报】目录。
#   zsh/fish 由 Ghostty 自动注入;但 macOS 自带的 /bin/bash(3.2)不支持 ——
#   连官方 ghostty.bash 的钩子都要求 bash >= 4.4。没有上报,新窗口只能回家目录。
#
# What it does: before each prompt, if cwd changed, emit OSC 7. Inside tmux the
#   sequence is wrapped in a passthrough envelope (needs `allow-passthrough on`,
#   already in our tmux.conf) so the OUTER Ghostty still sees the real cwd.
# 行为: 每次出 prompt 前,目录变了就发一条 OSC 7;在 tmux 里会包一层透传
#   信封(需要 `allow-passthrough on`,我们的 tmux.conf 已开),让外层 Ghostty
#   也能看到真实目录。
#
# Setup / 启用(zsh、fish 用户不需要,Ghostty 会自动注入):
#   echo '[ -f ~/.ghostty-cwd.bash ] && source ~/.ghostty-cwd.bash' >> ~/.bashrc
# Restore: copied to ~/.ghostty-cwd.bash by terminal/install.sh
# 复原:   由 terminal/install.sh 拷贝到 ~/.ghostty-cwd.bash
# ============================================================================

# Interactive shells only; guard against double-source (.bashrc is often
# sourced twice via .bash_profile).
# 仅交互式 shell;防重复 source(.bashrc 常被 .bash_profile source 两次)。
case $- in *i*) ;; *) return 0 2>/dev/null;; esac
[ -n "${__ghostty_cwd_loaded:-}" ] && return 0
__ghostty_cwd_loaded=1

__ghostty_cwd_report() {
  [ "$PWD" = "${__ghostty_cwd_last:-}" ] && return
  __ghostty_cwd_last="$PWD"
  # kitty-shell-cwd:// takes the raw path — no URL-encoding needed (same
  # scheme Ghostty's own integration uses).
  # kitty-shell-cwd:// 直接放原始路径,不用做 URL 编码(官方集成同款)。
  if [ -n "${TMUX:-}" ]; then
    # DCS passthrough: ESC inside the payload must be doubled.
    # DCS 透传:载荷里的 ESC 要写两遍。
    printf '\033Ptmux;\033\033]7;kitty-shell-cwd://%s%s\007\033\\' "${HOSTNAME:-}" "$PWD"
  else
    printf '\033]7;kitty-shell-cwd://%s%s\007' "${HOSTNAME:-}" "$PWD"
  fi
}

case ";${PROMPT_COMMAND:-};" in
  *";__ghostty_cwd_report;"*) ;;
  *) PROMPT_COMMAND="__ghostty_cwd_report${PROMPT_COMMAND:+; $PROMPT_COMMAND}";;
esac
