#!/usr/bin/env bash
# ============================================================================
# One-shot restore script for terminal config (macOS)
# terminal 配置一键复原脚本(macOS)
#   - copy Ghostty config -> ~/.config/ghostty/config | 拷贝 Ghostty 配置
#   - copy tmux config    -> ~/.tmux.conf             | 拷贝 tmux 配置
#   - install tpm (tmux plugin manager)               | 安装 tpm
# Files are COPIED (not symlinked). Existing files are backed up as *.bak.<ts>.
# 配置是【拷贝】(非软链)。已存在的旧文件会先备份成 *.bak.<时间戳>。
# After editing files in the repo, re-run this script to apply them.
# 在 repo 里改完配置后,重跑本脚本即可应用。
# Usage / 用法:  bash terminal/install.sh
# ============================================================================
set -euo pipefail

# Directory of this script (i.e. terminal/) | 脚本所在目录(即 terminal/)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

# copy_file <source> <target> | copy_file <源文件> <目标路径>
copy_file() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    echo "✗ source missing / 源文件缺失: $src" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    # Already identical regular file? skip. | 已是相同内容则跳过
    if [ -f "$dst" ] && ! [ -L "$dst" ] && cmp -s "$src" "$dst"; then
      echo "✓ already up to date / 已是最新: $dst"
      return 0
    fi
    echo "↪ backing up / 备份旧文件: $dst -> $dst.bak.$TS"
    cp -RL "$dst" "$dst.bak.$TS"   # -L: if it's an old symlink, back up its content | 旧软链则备份其内容
    rm -f "$dst"                    # clear any existing file/symlink | 清掉旧文件或软链
  fi
  cp "$src" "$dst"
  echo "✓ copied / 拷贝: $src -> $dst"
}

echo "== 1/3 Ghostty =="
copy_file "$DIR/ghostty/config" "$HOME/.config/ghostty/config"
# Old macOS builds may keep the live config at App Support/config.ghostty;
# back it up after migration to avoid double-loading.
# macOS 旧版可能把活配置放在 App Support 的 config.ghostty,迁移后备份掉以免重复加载。
LEGACY="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
if [ -e "$LEGACY" ]; then
  echo "↪ found legacy / 发现旧配置 $LEGACY -> backing up / 备份为 $LEGACY.bak.$TS"
  mv "$LEGACY" "$LEGACY.bak.$TS"
fi

echo "== 2/3 tmux =="
copy_file "$DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

echo "== 3/3 tpm (tmux plugin manager) / tpm(tmux 插件管理器)=="
TPM="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM" ]; then
  echo "✓ tpm already installed / 已安装"
else
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM"
  echo "✓ tpm cloned / 已克隆"
fi

# Sanity check: tmux.conf sets default-terminal "tmux-256color", which needs that
# terminfo entry. Modern macOS has it; very old systems may not.
# 检查:tmux.conf 用了 default-terminal "tmux-256color",需要该 terminfo 条目。
# 新版 macOS 自带;很老的系统可能缺。
if ! infocmp tmux-256color >/dev/null 2>&1; then
  echo "⚠ terminfo 'tmux-256color' not found / 未找到 tmux-256color terminfo"
  echo "  Colors/keys inside tmux may misbehave. Fix / 修复:"
  echo "  brew install ncurses   # or build it: https://gist.github.com/bbqtd/a4ac060d6f6b9ea6fe3aabe735aa9d95"
fi

cat <<'EOF'

Done ✅ / 完成 ✅   Next steps / 接下来:
  1) Ghostty: reopen, or press Cmd+Shift+, to reload
     Ghostty:重开,或在窗口里按 Cmd+Shift+, 重载配置
  2) tmux: run `tmux`, then press prefix (Ctrl+b) + I to install plugins
     tmux:启动 `tmux`,然后按 前缀(Ctrl+b)+ I 安装插件
  3) Verify persistence: prefix + Ctrl-s to save; restart tmux to auto-restore
     验证持久化:前缀 + Ctrl-s 手动存一次;重启 tmux 会自动恢复
  Note: edits in the repo are NOT live until you re-run this script.
  注意:在 repo 里改了配置后,需重跑本脚本才会生效。
EOF
