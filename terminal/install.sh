#!/usr/bin/env bash
# ============================================================================
# One-shot, ROLLBACKABLE installer for terminal config (macOS)
# 可一键回滚的 terminal 配置安装脚本(macOS)
#
# Usage / 用法:
#   bash terminal/install.sh [--lang=en|zh] [--yes] [--help]
#
# What it does / 做什么:
#   - Ghostty config      -> ~/.config/ghostty/config
#   - tmux config         -> ~/.tmux.conf (+ cheatsheet)
#   - gtmux CLI           -> ~/.local/bin/gtmux (overview / agents / restore / focus)
#                            installed via github.com/chenchaoyi/gtmux curl one-liner
#   - cwd reporter        -> ~/.ghostty-cwd.bash (for macOS bash 3.2)
#   - everything else     -> delegated to `gtmux doctor --fix`: tmux plugins
#                            (tpm/resurrect/continuum), set-titles, Claude Code
#                            hook (notifications), menu-bar app. gtmux explains
#                            each change, asks first, and keeps its own backups.
#   - 其余设置            -> 交给 `gtmux doctor --fix`:tmux 插件(tpm/resurrect/
#                            continuum)、set-titles、Claude Code hook(通知)、
#                            菜单栏 app。gtmux 逐项解释并征求确认,且自带备份。
#
#   Homebrew packages (Ghostty, tmux, browsing tools): see repo-root Brewfile
#   (`brew bundle --file=Brewfile`).
#   Homebrew 包(Ghostty、tmux、翻代码工具)见仓库根目录 Brewfile。
#
# SAFETY / 安全:
#   - Every replaced/removed file is backed up under
#     ~/.local/state/terminal-config/backups/<ts>/ with a generated rollback.sh
#     that undoes EVERYTHING from that run. On any error the script stops and
#     prints the rollback command.
#     每个被替换/移走的文件都备份到 ~/.local/state/terminal-config/backups/
#     <时间戳>/,并生成 rollback.sh 一键完全还原;出错即停并提示回滚命令。
#
# Output is single-language (default English; --lang=zh for Chinese).
# Source comments stay bilingual on purpose.
# 输出为单一语言(默认英文,--lang=zh 切中文);源码注释保持双语。
# ============================================================================
set -euo pipefail

# ---- CLI arguments / 命令行参数 ---------------------------------------------
UI_LANG=en
ASSUME_YES=0
SHOW_HELP=0
for arg in "$@"; do
  case "$arg" in
    --lang=zh|--lang=zh_CN) UI_LANG=zh;;
    --lang=en|--lang=en_US) UI_LANG=en;;
    --lang=*) printf 'Unknown --lang value: %s (expected en|zh)\n' "${arg#--lang=}" >&2; exit 2;;
    -y|--yes) ASSUME_YES=1;;
    -h|--help) SHOW_HELP=1;;
    *) printf 'Unknown option: %s (try --help)\n' "$arg" >&2; exit 2;;
  esac
done

# say <english> <chinese> — print one line in the selected language
# sayn — same, without trailing newline (for prompts)
say()  { if [ "$UI_LANG" = zh ]; then printf '%s\n' "$2"; else printf '%s\n' "$1"; fi; }
sayn() { if [ "$UI_LANG" = zh ]; then printf '%s'   "$2"; else printf '%s'   "$1"; fi; }
say_err() { say "$1" "$2" >&2; }

usage() {
  if [ "$UI_LANG" = zh ]; then
    cat <<'EOF'
用法: bash terminal/install.sh [选项]

一键安装本仓库的终端环境(macOS),全程可回滚:
Ghostty 配置、tmux 配置、gtmux 命令行、目录上报片段;其余设置
(插件/set-titles/通知 hook/菜单栏 app)由 `gtmux doctor --fix` 完成。

选项:
  --lang=en|zh   输出语言(默认 en)
  -y, --yes      自动确认所有询问(如 brew 升级)。不带此参数时,
                 仅在交互终端里询问;非交互运行绝不阻塞等待输入。
  -h, --help     显示本帮助并退出

行为说明(对人和 agent 同样适用):
  - 幂等:重复运行安全,内容未变的文件会跳过。
  - 每个被替换的文件都备份到 ~/.local/state/terminal-config/backups/<时间戳>/,
    该目录下的 rollback.sh 可完全撤销本次运行的全部改动。
  - 绝不修改任何 shell rc 文件;需要时只打印可复制的命令。
  - 输出标记: '== 步骤 ==' 分节,'✓' 成功,'↪' 已备份替换,'ℹ' 提示,
    '⚠' 非致命警告,'✗' 致命错误。
  - 退出码: 0 成功(可能含警告),1 致命错误(已打印回滚命令),2 参数错误。
EOF
  else
    cat <<'EOF'
Usage: bash terminal/install.sh [OPTIONS]

One-shot, rollbackable installer for this repo's terminal setup (macOS):
Ghostty config, tmux config, gtmux CLI, cwd reporter; the rest (plugins /
set-titles / notification hook / menu-bar app) is done by `gtmux doctor --fix`.

Options:
  --lang=en|zh   Output language (default: en)
  -y, --yes      Auto-confirm all prompts (e.g. brew upgrades). Without it,
                 prompts appear only on interactive TTYs; non-interactive
                 runs never block waiting for input.
  -h, --help     Show this help and exit

Behavior notes (for humans and agents alike):
  - Idempotent: safe to re-run; files with unchanged content are skipped.
  - Every replaced file is backed up under
    ~/.local/state/terminal-config/backups/<ts>/ where a generated
    rollback.sh undoes everything from that run.
  - Never edits any shell rc file; prints copy-paste commands instead.
  - Output markers: '== step ==' sections, '✓' ok, '↪' replaced+backed-up,
    'ℹ' info, '⚠' non-fatal warning, '✗' fatal error.
  - Exit codes: 0 success (warnings possible), 1 fatal error (rollback
    command printed), 2 usage error.
EOF
  fi
}
if [ "$SHOW_HELP" = 1 ]; then usage; exit 0; fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # = terminal/
TS="$(date +%Y%m%d-%H%M%S)"
# Backups live under the XDG state dir (out of the cluttered home root, and —
# unlike /tmp — they survive reboots so rollback always works).
# 备份放在 XDG state 目录(不污染 home 根目录;且不像 /tmp 那样重启被清,回滚始终可用)。
BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/terminal-config/backups/$TS"
ROLLBACK="$BACKUP_DIR/rollback.sh"

# ---- error trap / 错误陷阱 -------------------------------------------------
on_err() {
  local line=$1
  echo "" >&2
  say_err "✗ ERROR at line $line — install aborted." \
          "✗ 第 $line 行出错 —— 安装中止。"
  if [ -f "$ROLLBACK" ]; then
    say_err "  Partial changes can be undone with:" \
            "  已做的改动可用以下命令回滚:"
    echo "    bash \"$ROLLBACK\"" >&2
  fi
  exit 1
}
trap 'on_err $LINENO' ERR

# ---- init backup dir + rollback script / 初始化备份目录与回滚脚本 ----------
# The generated rollback.sh speaks the language chosen at install time.
# 生成的 rollback.sh 使用安装时选择的语言。
if [ "$UI_LANG" = zh ]; then
  R_HEAD="正在回滚 terminal 配置安装($TS)..."
  R_RESTORED="已还原"; R_REMOVED="已删除新建文件"
else
  R_HEAD="Rolling back terminal config install ($TS)..."
  R_RESTORED="restored"; R_REMOVED="removed (was new)"
fi
mkdir -p "$BACKUP_DIR"
cat > "$ROLLBACK" <<EOF
#!/usr/bin/env bash
# Auto-generated rollback for terminal config install at $TS
set -u
# Resolve this script's own dir so the backup folder can be moved freely.
BDIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
echo "$R_HEAD"
EOF
chmod +x "$ROLLBACK"

# helpers that append undo actions to rollback.sh / 往回滚脚本追加还原动作
record_restore() {  # <target> <backup-basename>  -> restore original on rollback
  printf 'cp -p "$BDIR/%s" %q && echo "  %s: %s"\n' "$2" "$1" "$R_RESTORED" "$1" >> "$ROLLBACK"
}
record_remove() {   # <target>           -> remove newly-created file on rollback
  printf 'rm -f %q && echo "  %s: %s"\n' "$1" "$R_REMOVED" "$1" >> "$ROLLBACK"
}

safe_backup() {     # <path> -> copies path into BACKUP_DIR, echoes backup BASENAME
  local src="$1"
  local name; name="$(printf '%s' "$src" | sed 's#/#_#g')"
  # -RL follows symlinks; fall back to plain -R for broken links
  cp -RL "$src" "$BACKUP_DIR/$name" 2>/dev/null || cp -R "$src" "$BACKUP_DIR/$name"
  printf '%s' "$name"
}

# install one file, recording how to undo it / 安装一个文件并记录回滚方式
install_file() {    # <src> <dst>
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    say_err "✗ source missing: $src" "✗ 源文件缺失: $src"
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
      say "✓ already up to date: $dst" "✓ 已是最新: $dst"
      return 0
    fi
    local bak; bak="$(safe_backup "$dst")"
    record_restore "$dst" "$bak"
    rm -f "$dst"
    say "↪ backed up old: $dst -> $bak" "↪ 已备份旧文件: $dst -> $bak"
  else
    record_remove "$dst"
  fi
  cp "$src" "$dst"
  say "✓ installed: $dst" "✓ 已安装: $dst"
}

# ---- preflight checks / 预检 -----------------------------------------------
# Version floors (what actually breaks below them) / 版本下限(低于会坏什么):
#   tmux    >= 3.3  allow-passthrough — cwd reporting & OSC through tmux
#   Ghostty >= 1.3  AppleScript dictionary — gtmux restore/focus need it
MIN_TMUX="3.3"
MIN_GHOSTTY="1.3"

version_ge() {  # version_ge <have> <want> -> 0 if have >= want (numeric, dotted)
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    for (i = 1; i <= (n > m ? n : m); i++) {
      xv = (i <= n ? x[i] : 0) + 0; yv = (i <= m ? y[i] : 0) + 0
      if (xv > yv) exit 0
      if (xv < yv) exit 1
    }
    exit 0
  }'
}

# Upgrade flow: --yes auto-confirms; otherwise ask only on a TTY; never block
# in non-interactive runs.
# 升级流程:--yes 自动确认;否则仅在交互终端询问;非交互运行绝不阻塞。
offer_brew_upgrade() {  # <brew upgrade args...>
  if [ "$ASSUME_YES" = 1 ]; then
    say "  upgrading via Homebrew (auto-confirmed by --yes)..." \
        "  正在用 Homebrew 升级(--yes 已自动确认)..."
    brew upgrade "$@" \
      || say "  ⚠ upgrade failed — continuing with current version" \
             "  ⚠ 升级失败 —— 继续使用当前版本"
  elif [ -t 0 ]; then
    sayn "  Upgrade now via Homebrew? [y/N] " "  现在用 Homebrew 升级吗?[y/N] "
    IFS= read -r ans || ans=""
    case "$ans" in
      y|Y|yes|YES)
        brew upgrade "$@" \
          || say "  ⚠ upgrade failed — continuing with current version" \
                 "  ⚠ 升级失败 —— 继续使用当前版本";;
      *) say "  skipped (later: brew upgrade $*)" \
             "  已跳过(稍后可手动: brew upgrade $*)";;
    esac
  else
    say "  (non-interactive run — upgrade later: brew upgrade $*)" \
        "  (非交互运行 —— 稍后手动升级: brew upgrade $*)"
  fi
}

say "== preflight ==" "== 预检 =="

# tmux: presence + version floor + newer-version offer
# tmux:存在性 + 版本下限 + 有新版则询问升级
if command -v tmux >/dev/null 2>&1; then
  TMUX_VER="$(tmux -V 2>/dev/null | sed 's/[^0-9.]//g')"
  if version_ge "${TMUX_VER:-0}" "$MIN_TMUX"; then
    say "✓ tmux $TMUX_VER (>= $MIN_TMUX)" "✓ tmux $TMUX_VER(>= $MIN_TMUX)"
    if command -v brew >/dev/null 2>&1 && brew list tmux >/dev/null 2>&1 \
       && [ -n "$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated tmux 2>/dev/null)" ]; then
      say "ℹ newer tmux available" "ℹ 有新版 tmux 可用"
      offer_brew_upgrade tmux
    fi
  else
    say "⚠ tmux $TMUX_VER < $MIN_TMUX — cwd reporting through tmux (allow-passthrough) won't work" \
        "⚠ tmux $TMUX_VER 低于 $MIN_TMUX —— tmux 内的目录上报(allow-passthrough)不可用"
    if command -v brew >/dev/null 2>&1 && brew list tmux >/dev/null 2>&1; then
      offer_brew_upgrade tmux
    else
      say "  update manually: brew install tmux" "  请手动更新: brew install tmux"
    fi
  fi
else
  say "⚠ tmux not installed (configs still install; get it: brew install tmux)" \
      "⚠ 未安装 tmux(配置仍会装好;安装: brew install tmux)"
fi

# Ghostty: presence + version floor + newer-version offer
# Ghostty:存在性 + 版本下限 + 有新版则询问升级
GHOSTTY_VER=""
if [ -d "/Applications/Ghostty.app" ]; then
  GHOSTTY_VER="$(defaults read /Applications/Ghostty.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || true)"
elif command -v ghostty >/dev/null 2>&1; then
  GHOSTTY_VER="$(ghostty +version 2>/dev/null | awk 'NR==1 {print $NF}')"
fi
if [ -n "$GHOSTTY_VER" ]; then
  if version_ge "$GHOSTTY_VER" "$MIN_GHOSTTY"; then
    say "✓ Ghostty $GHOSTTY_VER (>= $MIN_GHOSTTY)" "✓ Ghostty $GHOSTTY_VER(>= $MIN_GHOSTTY)"
    if command -v brew >/dev/null 2>&1 && brew list --cask ghostty >/dev/null 2>&1 \
       && [ -n "$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask ghostty 2>/dev/null)" ]; then
      say "ℹ newer Ghostty available (restart Ghostty after upgrading)" \
          "ℹ 有新版 Ghostty 可用(升级后需重开 Ghostty)"
      offer_brew_upgrade --cask ghostty
    fi
  else
    say "⚠ Ghostty $GHOSTTY_VER < $MIN_GHOSTTY — gtmux restore (one-shot) & focus (AppleScript) won't work; restore --one still does" \
        "⚠ Ghostty $GHOSTTY_VER 低于 $MIN_GHOSTTY —— gtmux restore 一键模式与 focus(AppleScript)不可用,restore --one 不受影响"
    if command -v brew >/dev/null 2>&1 && brew list --cask ghostty >/dev/null 2>&1; then
      offer_brew_upgrade --cask ghostty
    else
      say "  update manually: brew install --cask ghostty, or download from ghostty.org" \
          "  请手动更新: brew install --cask ghostty,或从 ghostty.org 下载"
    fi
  fi
else
  say "⚠ Ghostty not found (configs still install; get it: brew install --cask ghostty)" \
      "⚠ 未找到 Ghostty(配置仍会装好;安装: brew install --cask ghostty)"
fi
say "  backups + rollback: $BACKUP_DIR" "  备份与回滚: $BACKUP_DIR"

# ---- 1) Ghostty config / Ghostty 配置 -------------------------------------
say "== 1/5 Ghostty config ==" "== 1/5 Ghostty 配置 =="
install_file "$DIR/ghostty/config" "$HOME/.config/ghostty/config"
# Legacy non-standard config.ghostty: back it up and disable to avoid double-load
# 旧的非标准 config.ghostty:备份并停用,避免与新配置重复加载
LEGACY="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
if [ -e "$LEGACY" ]; then
  bak="$(safe_backup "$LEGACY")"
  record_restore "$LEGACY" "$bak"     # rollback puts it back
  mv "$LEGACY" "$LEGACY.disabled-$TS"
  printf 'rm -f %q\n' "$LEGACY.disabled-$TS" >> "$ROLLBACK"   # tidy the disabled copy on rollback
  say "↪ legacy config disabled: $LEGACY -> $LEGACY.disabled-$TS (backup: $bak)" \
      "↪ 旧配置已停用: $LEGACY -> $LEGACY.disabled-$TS(备份: $bak)"
fi

# ---- 2) tmux config + cheatsheet / tmux 配置 + 速查表 -----------------------
say "== 2/5 tmux config ==" "== 2/5 tmux 配置 =="
install_file "$DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
# Quick-reference shown by the prefix+g popup / 前缀+g 弹窗显示的速查表
install_file "$DIR/tmux/cheatsheet.txt" "$HOME/.tmux-cheatsheet.txt"

# ---- 3) gtmux CLI / gtmux 命令行 --------------------------------------------
# A standalone, shell-agnostic CLI on PATH (~/.local/bin). One command, three
# verbs: `gtmux restore` (reattach all sessions), `gtmux overview` (the prefix+g
# popup, also runnable from any shell), `gtmux focus <name>` (jump to a tab).
# 安装到 PATH(~/.local/bin)的独立命令行,与 shell 配置无关。一个命令三个动词:
# `gtmux restore`(一键接回全部 session)、`gtmux overview`(前缀+g 弹窗,也可直接跑)、
# `gtmux focus <名字>`(跳到对应 tab)。
say "== 3/5 CLI tool (gtmux) ==" "== 3/5 命令行工具(gtmux)=="
# gtmux now lives in its own repo (github.com/chenchaoyi/gtmux) and is installed
# via its curl one-liner, which fetches a prebuilt, checksum-verified binary
# (GitHub-first, with a CN mirror-chain fallback). No local Go toolchain needed.
# We bootstrap the installer SCRIPT itself with the same direct→mirror fallback
# (raw.githubusercontent.com is also often blocked on CN networks), then fall
# back to `go install` if the script can't be fetched at all.
# gtmux 已拆成独立仓库(github.com/chenchaoyi/gtmux),用它的 curl 一行命令安装:
# 拉取预编译、经校验和验证的二进制(优先 GitHub,失败回退国内镜像链),无需本机 Go。
# 安装器脚本本身也用「直连→镜像」回退获取(raw.githubusercontent.com 在国内也常被墙),
# 都拿不到时再退回 `go install`。
_gtmux_raw="https://raw.githubusercontent.com/chenchaoyi/gtmux/main/install.sh"
_gtmux_script="$(mktemp)"
_gtmux_got=""
for _pre in "" "https://ghfast.top/" "https://gh-proxy.com/"; do
  if curl -fsSL --max-time 20 "${_pre}${_gtmux_raw}" -o "$_gtmux_script" 2>/dev/null \
     && head -1 "$_gtmux_script" | grep -q '^#!.*bash'; then
    _gtmux_got=1; break
  fi
done
if [ -n "$_gtmux_got" ]; then
  # The gtmux installer drops the binary at ~/.local/bin/gtmux and handles
  # release-asset mirrors itself. Record it so this installer's rollback removes it.
  if bash "$_gtmux_script"; then
    record_remove "$HOME/.local/bin/gtmux"
  else
    say_err "✗ gtmux install failed — see output above; re-run or install manually" \
            "✗ gtmux 安装失败 —— 见上方输出;可重跑或手动安装"
  fi
elif command -v go >/dev/null 2>&1; then
  say "⚠ couldn't fetch the gtmux installer — falling back to 'go install'" \
      "⚠ 拉取 gtmux 安装器失败 —— 回退到 'go install'"
  if GOBIN="$HOME/.local/bin" go install github.com/chenchaoyi/gtmux/cmd/gtmux@latest; then
    record_remove "$HOME/.local/bin/gtmux"
  else
    say_err "✗ go install gtmux failed — install manually: $_gtmux_raw" \
            "✗ go install gtmux 失败 —— 请手动安装: $_gtmux_raw"
  fi
else
  say_err "⚠ gtmux not installed — no network for the installer and no Go. Run later:" \
          "⚠ 未安装 gtmux —— 无法获取安装器且无 Go。稍后运行:"
  say "    curl -fsSL $_gtmux_raw | bash" \
      "    curl -fsSL $_gtmux_raw | bash"
fi
rm -f "$_gtmux_script" 2>/dev/null
# Legacy CLIs folded into gtmux: back up and remove the old standalone names
# (~/.local/bin/tmux-restore, ~/.local/bin/tmux-overview, ~/tmux-restore).
# 旧的两个独立命令行已并入 gtmux:备份后移除旧名字。
for legacy in "$HOME/.local/bin/tmux-restore" "$HOME/.local/bin/tmux-overview" "$HOME/tmux-restore"; do
  if [ -f "$legacy" ]; then
    bak="$(safe_backup "$legacy")"
    record_restore "$legacy" "$bak"
    rm -f "$legacy"
    say "↪ legacy CLI removed: $legacy → now 'gtmux' (backup: $bak)" \
        "↪ 旧命令行已移除: $legacy → 改用 'gtmux'(备份: $bak)"
  fi
done
# PATH sanity check — ~/.local/bin is the XDG-standard user-bin dir, but macOS
# does not put it on PATH by default; give a shell-specific one-liner.
# PATH 检查 —— ~/.local/bin 是 XDG 标准的用户可执行目录,但 macOS 默认不在
# PATH 里;按用户的 shell 给出对应的一行命令。
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *)
    say "⚠ ~/.local/bin is not on your PATH — run:" \
        "⚠ ~/.local/bin 不在 PATH 中 —— 请运行:"
    case "$(basename "${SHELL:-/bin/bash}")" in
      zsh)  echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc";;
      fish) echo "    fish_add_path ~/.local/bin";;
      *)    echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc";;
    esac;;
esac

# ---- 4) cwd reporter for old bash / 旧版 bash 的目录上报 --------------------
# macOS /bin/bash (3.2) gets no automatic Ghostty shell integration, so new
# windows/tabs can't inherit the cwd. This snippet adds minimal OSC 7 reporting
# (works through tmux too). bash users source it in .bashrc — see final notes.
# macOS 自带 /bin/bash(3.2)没有 Ghostty 自动 shell 集成,新窗口/新 tab 无法
# 继承工作目录。该片段补上最小化 OSC 7 上报(tmux 内同样生效)。bash 用户在
# .bashrc 里 source 它 —— 见结尾说明。
say "== 4/5 cwd reporter ==" "== 4/5 目录上报片段 =="
install_file "$DIR/shell/ghostty-cwd.bash" "$HOME/.ghostty-cwd.bash"

# ---- terminfo sanity check / terminfo 检查 --------------------------------
if ! infocmp tmux-256color >/dev/null 2>&1; then
  say "⚠ terminfo 'tmux-256color' not found — colors/keys inside tmux may misbehave (fix: brew install ncurses)" \
      "⚠ 未找到 tmux-256color terminfo —— tmux 内颜色或按键可能异常(修复: brew install ncurses)"
fi

# ---- 5) finish setup via gtmux / 其余设置交给 gtmux ------------------------
# Everything beyond the config files is gtmux's own domain, and `gtmux doctor
# --fix` now handles all of it: tmux plugins (tpm/resurrect/continuum, cloned
# directly — no prefix+I needed), set-titles + restore options (skipped when our
# tmux.conf already provides them), the Claude Code hook (agent-done
# notifications; the menu-bar app delivers them — terminal-notifier is no longer
# used), and the menu-bar app itself. It explains each change, asks first
# (--yes applies all), and keeps its OWN backups (~/.tmux.conf.gtmux.bak,
# settings.json backups) — so this part is outside our rollback.sh.
# 配置文件之外的设置都属于 gtmux 自己的领域,现在由 `gtmux doctor --fix` 一站完成:
# tmux 插件(tpm/resurrect/continuum,直接 clone,无需 prefix+I)、set-titles 与
# 恢复选项(我们的 tmux.conf 已提供时自动跳过)、Claude Code hook(agent 完成通知;
# 通知由菜单栏 app 发出,不再依赖 terminal-notifier)、以及菜单栏 app 本身。
# 它逐项解释并征求确认(--yes 全部应用),且自带备份(~/.tmux.conf.gtmux.bak、
# settings.json 备份)—— 这部分不在本脚本的 rollback.sh 范围内。
say "== 5/5 finish setup (gtmux doctor --fix) ==" "== 5/5 完成其余设置(gtmux doctor --fix)=="
GTMUX_BIN="$HOME/.local/bin/gtmux"
if [ ! -x "$GTMUX_BIN" ]; then
  say "⚠ gtmux not installed — finish later with: gtmux doctor --fix" \
      "⚠ 未安装 gtmux —— 稍后手动完成: gtmux doctor --fix"
elif ! command -v tmux >/dev/null 2>&1; then
  say "⚠ tmux not installed — after installing it, run: gtmux doctor --fix" \
      "⚠ 未安装 tmux —— 装好后运行: gtmux doctor --fix"
elif [ "$ASSUME_YES" = 1 ]; then
  "$GTMUX_BIN" --lang="$UI_LANG" doctor --fix --yes \
    || say "⚠ 'gtmux doctor --fix' reported problems — re-run: gtmux doctor --fix" \
           "⚠ 'gtmux doctor --fix' 报告了问题 —— 可重跑: gtmux doctor --fix"
elif [ -t 0 ]; then
  say "ℹ handing off to gtmux — it asks before each change (Ctrl-C skips the rest)" \
      "ℹ 交给 gtmux —— 每个改动它都会先询问(Ctrl-C 跳过剩余步骤)"
  "$GTMUX_BIN" --lang="$UI_LANG" doctor --fix \
    || say "⚠ 'gtmux doctor --fix' reported problems — re-run: gtmux doctor --fix" \
           "⚠ 'gtmux doctor --fix' 报告了问题 —— 可重跑: gtmux doctor --fix"
else
  say "ℹ non-interactive run — finish setup later with: gtmux doctor --fix" \
      "ℹ 非交互运行 —— 稍后完成其余设置: gtmux doctor --fix"
fi

# ---- done / 完成 -----------------------------------------------------------
if [ "$UI_LANG" = zh ]; then
  cat <<EOF

完成 ✅

回滚:  bash "$ROLLBACK"
  (还原本脚本安装的配置文件;gtmux doctor --fix 的改动由 gtmux 自身备份,
   如 ~/.tmux.conf.gtmux.bak 与 settings.json 备份)

接下来:
  1) Ghostty:重开,或按 Cmd+Shift+, 重载配置
  2) tmux:先 'tmux kill-server' 再开 'tmux' —— 插件由 doctor --fix 装好,直接用
  3) 验证持久化:前缀 + Ctrl-s 手动存一次
  注意:在 repo 里改了配置后,需重跑本脚本才生效。随时可跑 'gtmux doctor' 体检。

gtmux —— tmux 会话与 coding agent 的指挥台(四个动词;裸 gtmux 看帮助):
  gtmux agents [--watch]   看 agent:谁在跑/空闲/等你(--watch 实时面板;也可 前缀+a)
  gtmux overview          看现状:session/window/pane 汇总(等同前缀+g 弹窗)
  gtmux focus <名字>       跳转:把显示该 session 的 Ghostty tab 拉到最前
  gtmux restore           接回:重开 Ghostty 后,在任意 tab、任意目录运行【一次】,
                          为每个 session 开一个 tab 并全部接回(需 Ghostty 1.3+;
                          首次弹自动化授权,点允许)。其它模式:
      gtmux restore --pick   (列出并选择接回哪几个)
      gtmux restore --one    (当前 tab 接回下一个无人连接的)
      gtmux restore <名字>    (指定 session)
  电脑【重启】后(tmux server 已不在)restore 同样适用:会启动 tmux 并由 continuum
  恢复最近的自动存档(每 5 分钟一次;目录和屏幕文本会回来,运行中的程序不会)。

新窗口继承工作目录:
  zsh / fish:开箱即用(Ghostty 自动注入 shell 集成)。
  bash(macOS 自带 3.2):不支持自动注入 —— 在 ~/.bashrc 里加【一行】,
  新窗口/新 tab(含 tmux 内)即可继承当前目录:
      [ -f ~/.ghostty-cwd.bash ] && source ~/.ghostty-cwd.bash
EOF
else
  cat <<EOF

Done ✅

ROLLBACK:  bash "$ROLLBACK"
  (restores the config files this script installed; changes made by
   'gtmux doctor --fix' have gtmux's own backups, e.g. ~/.tmux.conf.gtmux.bak
   and settings.json backups)

Next steps:
  1) Ghostty: reopen, or press Cmd+Shift+, to reload the config
  2) tmux: 'tmux kill-server' then 'tmux' — plugins were installed by doctor --fix
  3) Verify persistence: prefix + Ctrl-s to save once
  Note: repo edits are NOT live until you re-run this script.
  Health check anytime: 'gtmux doctor'.

gtmux — command center for tmux sessions + coding agents (four verbs; bare gtmux = help):
  gtmux agents [--watch]  AGENTS: who's working / idle / waiting on you (--watch live; or prefix+a)
  gtmux overview          SEE: sessions/windows/panes summary (= the prefix+g popup)
  gtmux focus <name>      JUMP: bring the Ghostty tab showing that session to front
  gtmux restore           BUILD: after reopening Ghostty, run ONCE in any tab, from
                          any directory — opens one tab per session and attaches all
                          (needs Ghostty 1.3+; first run asks for Automation
                          permission — Allow it). Other modes:
      gtmux restore --pick   (list sessions, choose which)
      gtmux restore --one    (attach the next unattached session here)
      gtmux restore <name>   (a specific session)
  After a machine REBOOT (tmux server gone) 'gtmux restore' still works: it starts
  tmux and tmux-continuum restores the last autosave (every 5 min; dirs + screen
  text come back, running programs are not restarted).

Working-directory inheritance:
  zsh / fish: works out of the box (Ghostty auto-injects shell integration).
  bash (macOS /bin/bash 3.2): auto-injection is NOT supported — add ONE line
  to your ~/.bashrc so new windows/tabs (and tmux panes) inherit the cwd:
      [ -f ~/.ghostty-cwd.bash ] && source ~/.ghostty-cwd.bash
EOF
fi
