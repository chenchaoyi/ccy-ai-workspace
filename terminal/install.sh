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
echo "== preflight / 预检 =="
command -v tmux >/dev/null 2>&1 \
  && echo "✓ tmux: $(tmux -V)" \
  || echo "⚠ tmux not installed / 未安装(配置仍会装好;用 brew install tmux 安装)"
command -v ghostty >/dev/null 2>&1 || [ -d "/Applications/Ghostty.app" ] \
  && echo "✓ Ghostty present / 已安装" \
  || echo "⚠ Ghostty not found / 未找到(配置仍会装好)"
echo "  backups + rollback / 备份与回滚: $BACKUP_DIR"

# ---- 1) Ghostty config / Ghostty 配置 -------------------------------------
echo "== 1/3 Ghostty =="
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
echo "== 2/3 tmux =="
install_file "$DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

# ---- 3) tpm (non-fatal) / tpm(失败不致命)--------------------------------
echo "== 3/4 tpm (tmux plugin manager) =="
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

# ---- 4/4 install tmux plugins headlessly / 无头自动安装 tmux 插件 ----------
# No need to press prefix+I by hand — installed here via an ISOLATED tmux server
# (-L socket) so your running tmux, if any, is never touched.
# 不用手动按 前缀+I —— 这里用【独立 socket 的 tmux server】自动装好,绝不碰你正在跑的 tmux。
echo "== 4/4 tmux plugins / 自动安装 tmux 插件 =="
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
EOF
