#!/usr/bin/env bash
# ============================================================================
# One-shot, ROLLBACKABLE installer for terminal config (macOS)
# 可一键回滚的 terminal 配置安装脚本(macOS)
#
# What it does / 做什么:
#   - copy Ghostty config -> ~/.config/ghostty/config   | 拷贝 Ghostty 配置
#   - back up & disable any legacy ~/Library/.../config.ghostty
#     备份并停用旧的 config.ghostty(避免重复加载)
#   - copy tmux config    -> ~/.tmux.conf               | 拷贝 tmux 配置
#   - install tmux-restore CLI -> ~/.local/bin/tmux-restore (callable from any
#     directory; reattaches sessions after reopening Ghostty; shell-agnostic)
#     安装 tmux-restore 命令行 -> ~/.local/bin/tmux-restore(任意目录可调用;
#     重开 Ghostty 后一键接回全部 session;不依赖任何 shell 配置)
#   - copy cwd reporter   -> ~/.ghostty-cwd.bash (bash-3.2 users source it in
#     .bashrc so new windows/tabs inherit the working directory)
#     拷贝目录上报片段 -> ~/.ghostty-cwd.bash(bash 3.2 用户在 .bashrc 里
#     source 它,新窗口/新 tab 才能继承工作目录)
#   - install tpm + tmux plugins (headless, no prefix+I) | 安装 tpm 与插件(无头,无需 前缀+I)
#
# SAFETY / 安全:
#   - Every replaced/removed file is copied to
#     ~/.local/state/terminal-config/backups/<ts>/  (out of home root; survives reboot)
#     每个被替换/移走的文件都会复制到 ~/.local/state/terminal-config/backups/<时间戳>/
#   - A rollback.sh is generated there; run it to undo EVERYTHING.
#     该目录下会生成 rollback.sh,运行它即可【完全还原】。
#   - On any error the script stops and tells you the rollback command.
#     出错即停,并告知回滚命令。
#
# Usage / 用法:  bash terminal/install.sh
# ============================================================================
set -euo pipefail

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
  echo "✗ ERROR at line $line — install aborted. / 第 $line 行出错,安装中止。" >&2
  if [ -f "$ROLLBACK" ]; then
    echo "  Partial changes can be undone / 已做的改动可回滚:" >&2
    echo "    bash \"$ROLLBACK\"" >&2
  fi
  exit 1
}
trap 'on_err $LINENO' ERR

# ---- init backup dir + rollback script / 初始化备份目录与回滚脚本 ----------
mkdir -p "$BACKUP_DIR"
cat > "$ROLLBACK" <<EOF
#!/usr/bin/env bash
# Auto-generated rollback for terminal config install at $TS
# 由安装脚本自动生成的回滚脚本($TS)
set -u
# Resolve this script's own dir so the backup folder can be moved freely.
# 解析脚本自身目录,这样备份文件夹可以随意移动而不失效。
BDIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
echo "Rolling back terminal config install ($TS)... / 正在回滚..."
EOF
chmod +x "$ROLLBACK"

# helpers that append undo actions to rollback.sh / 往回滚脚本追加还原动作
record_restore() {  # <target> <backup-basename>  -> restore original on rollback
  printf 'cp -p "$BDIR/%s" %q && echo "  restored / 已还原: %s"\n' "$2" "$1" "$1" >> "$ROLLBACK"
}
record_remove() {   # <target>           -> remove newly-created file on rollback
  printf 'rm -f %q && echo "  removed (was new) / 已删除新建: %s"\n' "$1" "$1" >> "$ROLLBACK"
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
    echo "✗ source missing / 源文件缺失: $src" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
      echo "✓ already up to date / 已是最新: $dst"
      return 0
    fi
    local bak; bak="$(safe_backup "$dst")"
    record_restore "$dst" "$bak"
    rm -f "$dst"
    echo "↪ backed up old / 备份旧文件: $dst -> $bak"
  else
    record_remove "$dst"
  fi
  cp "$src" "$dst"
  echo "✓ installed / 安装: $dst"
}

# ---- preflight checks / 预检 -----------------------------------------------
# Version floors (what actually breaks below them) / 版本下限(低于会坏什么):
#   tmux    >= 3.3  allow-passthrough — cwd reporting & OSC through tmux
#                   OSC 透传(tmux 内目录上报)需要它
#   Ghostty >= 1.3  AppleScript dictionary — tmux-restore's one-shot mode
#                   AppleScript 字典(tmux-restore 一键模式)需要它
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

# Ask before upgrading; in non-interactive runs just print the command.
# 升级前先确认;非交互运行时只打印命令。
offer_brew_upgrade() {  # <brew upgrade args...>
  if [ -t 0 ]; then
    printf '  Upgrade now via Homebrew? / 现在用 Homebrew 升级吗? [y/N] '
    IFS= read -r ans || ans=""
    case "$ans" in
      y|Y|yes|YES)
        brew upgrade "$@" \
          || echo "  ⚠ upgrade failed — continuing with current version / 升级失败,继续用当前版本";;
      *) echo "  skipped / 已跳过(稍后可手动: brew upgrade $*)";;
    esac
  else
    echo "  (non-interactive run — upgrade later / 非交互运行,稍后手动: brew upgrade $*)"
  fi
}

echo "== preflight / 预检 =="

# tmux: presence + version floor + newer-version offer
# tmux:存在性 + 版本下限 + 有新版则询问升级
if command -v tmux >/dev/null 2>&1; then
  TMUX_VER="$(tmux -V 2>/dev/null | sed 's/[^0-9.]//g')"
  if version_ge "${TMUX_VER:-0}" "$MIN_TMUX"; then
    echo "✓ tmux $TMUX_VER (>= $MIN_TMUX)"
    if command -v brew >/dev/null 2>&1 && brew list tmux >/dev/null 2>&1 \
       && [ -n "$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated tmux 2>/dev/null)" ]; then
      echo "ℹ newer tmux available / 有新版 tmux 可用"
      offer_brew_upgrade tmux
    fi
  else
    echo "⚠ tmux $TMUX_VER < $MIN_TMUX — cwd reporting through tmux (allow-passthrough) won't work"
    echo "  tmux $TMUX_VER 低于 $MIN_TMUX —— tmux 内的目录上报(allow-passthrough)不可用"
    if command -v brew >/dev/null 2>&1 && brew list tmux >/dev/null 2>&1; then
      offer_brew_upgrade tmux
    else
      echo "  update manually / 请手动更新: brew install tmux"
    fi
  fi
else
  echo "⚠ tmux not installed / 未安装(配置仍会装好;安装: brew install tmux)"
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
    echo "✓ Ghostty $GHOSTTY_VER (>= $MIN_GHOSTTY)"
    if command -v brew >/dev/null 2>&1 && brew list --cask ghostty >/dev/null 2>&1 \
       && [ -n "$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask ghostty 2>/dev/null)" ]; then
      echo "ℹ newer Ghostty available / 有新版 Ghostty 可用(升级后需重开 Ghostty)"
      offer_brew_upgrade --cask ghostty
    fi
  else
    echo "⚠ Ghostty $GHOSTTY_VER < $MIN_GHOSTTY — tmux-restore's one-shot mode (AppleScript) won't work; --one still does"
    echo "  Ghostty $GHOSTTY_VER 低于 $MIN_GHOSTTY —— tmux-restore 一键模式(AppleScript)不可用,--one 模式不受影响"
    if command -v brew >/dev/null 2>&1 && brew list --cask ghostty >/dev/null 2>&1; then
      offer_brew_upgrade --cask ghostty
    else
      echo "  update manually / 请手动更新: brew install --cask ghostty 或从 ghostty.org 下载"
    fi
  fi
else
  echo "⚠ Ghostty not found / 未找到(配置仍会装好;安装: brew install --cask ghostty)"
fi
echo "  backups + rollback / 备份与回滚: $BACKUP_DIR"

# ---- 1) Ghostty config / Ghostty 配置 -------------------------------------
echo "== 1/6 Ghostty =="
install_file "$DIR/ghostty/config" "$HOME/.config/ghostty/config"
# Legacy non-standard config.ghostty: back it up and disable to avoid double-load
# 旧的非标准 config.ghostty:备份并停用,避免与新配置重复加载
LEGACY="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
if [ -e "$LEGACY" ]; then
  bak="$(safe_backup "$LEGACY")"
  record_restore "$LEGACY" "$bak"     # rollback puts it back
  mv "$LEGACY" "$LEGACY.disabled-$TS"
  printf 'rm -f %q\n' "$LEGACY.disabled-$TS" >> "$ROLLBACK"   # tidy the disabled copy on rollback
  echo "↪ legacy disabled / 旧配置已停用: $LEGACY -> $LEGACY.disabled-$TS (backup at $bak)"
fi

# ---- 2) tmux config / tmux 配置 -------------------------------------------
echo "== 2/6 tmux =="
install_file "$DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

# ---- 3) tmux-restore CLI / tmux-restore 命令行 ------------------------------
# A standalone, shell-agnostic CLI on PATH (~/.local/bin): run `tmux-restore`
# from any directory after reopening Ghostty to reattach every tmux session.
# 安装到 PATH(~/.local/bin)的独立命令行,与 shell 配置无关:重开 Ghostty 后
# 在任意目录运行 `tmux-restore` 即可一键接回全部 tmux session。
echo "== 3/6 tmux-restore CLI =="
install_file "$DIR/scripts/tmux-restore" "$HOME/.local/bin/tmux-restore"
chmod +x "$HOME/.local/bin/tmux-restore"
# Legacy home-dir copy from earlier installs: back up and remove
# 早期版本装在 home 根目录的旧副本:备份后移除
if [ -f "$HOME/tmux-restore" ]; then
  bak="$(safe_backup "$HOME/tmux-restore")"
  record_restore "$HOME/tmux-restore" "$bak"
  rm -f "$HOME/tmux-restore"
  echo "↪ legacy removed / 旧位置副本已移除: ~/tmux-restore (backup at $bak)"
fi
# PATH sanity check — ~/.local/bin is the XDG-standard user-bin dir, but macOS
# does not put it on PATH by default; give a shell-specific one-liner.
# PATH 检查 —— ~/.local/bin 是 XDG 标准的用户可执行目录,但 macOS 默认不在
# PATH 里;按用户的 shell 给出对应的一行命令。
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *)
    echo "⚠ ~/.local/bin is not on your PATH — run / 不在 PATH 中,请运行:"
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
echo "== 4/6 cwd reporter / 目录上报片段 =="
install_file "$DIR/shell/ghostty-cwd.bash" "$HOME/.ghostty-cwd.bash"

# ---- 5) tpm (non-fatal) / tpm(失败不致命)--------------------------------
echo "== 5/6 tpm (tmux plugin manager) =="
TPM="$HOME/.tmux/plugins/tpm"
PLUGINS_DIR="$HOME/.tmux/plugins"
FRESH_TPM=0
if [ -d "$TPM" ]; then
  echo "✓ tpm already installed / 已安装(未改动)"
elif ! command -v git >/dev/null 2>&1; then
  echo "⚠ git not found, skipping tpm / 未找到 git,跳过 tpm"
  echo "  later: git clone https://github.com/tmux-plugins/tpm $TPM"
else
  if git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM" 2>/dev/null; then
    FRESH_TPM=1
    echo "✓ tpm cloned / 已克隆"
  else
    echo "⚠ tpm clone failed (network?) / 克隆失败(可能无网络)。配置不受影响。"
    echo "  later / 稍后手动: git clone https://github.com/tmux-plugins/tpm $TPM"
  fi
fi

# ---- 6/6 install tmux plugins headlessly / 无头自动安装 tmux 插件 ----------
# No need to press prefix+I by hand — installed here via an ISOLATED tmux server
# (-L socket) so your running tmux, if any, is never touched.
# 不用手动按 前缀+I —— 这里用【独立 socket 的 tmux server】自动装好,绝不碰你正在跑的 tmux。
echo "== 6/6 tmux plugins / 自动安装 tmux 插件 =="
if [ -x "$TPM/bin/install_plugins" ] && command -v tmux >/dev/null 2>&1; then
  NEW_PLUGINS=""
  for p in tmux-resurrect tmux-continuum; do
    [ -d "$PLUGINS_DIR/$p" ] || NEW_PLUGINS="$NEW_PLUGINS $p"
  done
  SOCK="tpm-bootstrap-$$"
  if tmux -L "$SOCK" new-session -d -x 200 -y 50 2>/dev/null; then
    tmux -L "$SOCK" source-file "$HOME/.tmux.conf" 2>/dev/null || true
    tmux -L "$SOCK" run-shell "$TPM/bin/install_plugins" 2>/dev/null || true
    tmux -L "$SOCK" kill-server 2>/dev/null || true
  fi
  if [ -d "$PLUGINS_DIR/tmux-resurrect" ] && [ -d "$PLUGINS_DIR/tmux-continuum" ]; then
    echo "✓ plugins installed (resurrect + continuum) / 插件已自动安装,无需手动操作"
    # rollback: if WE created tpm the whole plugins dir is ours; else drop only new ones
    # 回滚:若 tpm 是本次新建,整个 plugins 目录都是我们的;否则只删本次新增的插件
    if [ "$FRESH_TPM" = 1 ]; then
      printf 'rm -rf %q && echo "  removed plugins / 已删除插件目录: %s"\n' "$PLUGINS_DIR" "$PLUGINS_DIR" >> "$ROLLBACK"
    else
      for p in $NEW_PLUGINS; do
        printf 'rm -rf %q && echo "  removed plugin / 已删除插件: %s"\n' "$PLUGINS_DIR/$p" "$p" >> "$ROLLBACK"
      done
    fi
  else
    echo "⚠ auto-install incomplete; in tmux press prefix(Ctrl+b)+I to finish"
    echo "  自动安装未完成;进 tmux 后按 前缀(Ctrl+b)+I 手动补装"
    [ "$FRESH_TPM" = 1 ] && printf 'rm -rf %q\n' "$TPM" >> "$ROLLBACK"
  fi
else
  echo "⚠ tpm/tmux not ready; in tmux press prefix(Ctrl+b)+I / 进 tmux 按 前缀+I"
  [ "$FRESH_TPM" = 1 ] && printf 'rm -rf %q\n' "$TPM" >> "$ROLLBACK"
fi

# ---- terminfo sanity check / terminfo 检查 --------------------------------
if ! infocmp tmux-256color >/dev/null 2>&1; then
  echo "⚠ terminfo 'tmux-256color' not found / 未找到 tmux-256color terminfo"
  echo "  Colors/keys inside tmux may misbehave. / tmux 内颜色或按键可能异常。"
  echo "  fix: brew install ncurses"
fi

# ---- done / 完成 -----------------------------------------------------------
cat <<EOF

Done ✅ / 完成 ✅

ROLLBACK / 回滚:  bash "$ROLLBACK"
  (restores Ghostty + tmux to exactly how they were before this run)
  (把 Ghostty 与 tmux 完全还原到本次安装前的状态)

Next steps / 接下来:
  1) Ghostty: reopen, or Cmd+Shift+, to reload | 重开,或 Cmd+Shift+, 重载
  2) tmux: 'tmux kill-server' then 'tmux' — plugins are already installed
     tmux:先 'tmux kill-server' 再开 'tmux' —— 插件已自动装好,直接用
  3) Verify persistence: prefix + Ctrl-s to save | 验证持久化:前缀 + Ctrl-s
  Note: repo edits are NOT live until you re-run this script.
  注意:在 repo 改了配置后需重跑本脚本才生效。

Reattaching tmux sessions / 接回 tmux session:
  After reopening Ghostty, run ONCE in any tab, from any directory:
  重开 Ghostty 后,在任意 tab、任意目录下运行【一次】:
      tmux-restore
  It opens one Ghostty tab per tmux session and attaches them all
  (needs Ghostty 1.3+; first run asks for Automation permission — Allow it).
  它会为每个 tmux session 开一个 Ghostty tab 并全部接回
  (需 Ghostty 1.3+;首次运行会弹自动化授权,点允许)。
  Other modes / 其它模式:
      tmux-restore --pick   (list sessions, choose which / 列出并选择接回哪几个)
      tmux-restore --one    (next unattached session / 下一个无人连接的)
      tmux-restore <name>   (a specific session / 指定 session)
  After a machine REBOOT (tmux server gone) the same commands still work:
  they start tmux and tmux-continuum restores the last autosave (every 5 min;
  dirs + screen text come back, running programs are not restarted).
  电脑【重启】后(tmux server 已不在)同样适用:会启动 tmux 并由 continuum
  恢复最近的自动存档(每 5 分钟一次;目录+屏幕文本会回来,运行中的程序不会)。

Working-directory inheritance / 新窗口继承工作目录:
  zsh / fish: works out of the box (Ghostty auto-injects shell integration).
  zsh / fish:开箱即用(Ghostty 自动注入 shell 集成)。
  bash (macOS /bin/bash 3.2): auto-injection is NOT supported — add ONE line
  to your ~/.bashrc so new windows/tabs (and tmux panes) inherit the cwd:
  bash(macOS 自带 3.2):不支持自动注入 —— 在 ~/.bashrc 里加【一行】,
  新窗口/新 tab(含 tmux 内)即可继承当前目录:
      [ -f ~/.ghostty-cwd.bash ] && source ~/.ghostty-cwd.bash
EOF
