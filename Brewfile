# ============================================================================
# Brewfile — every Homebrew package this workspace expects, in one command:
# Brewfile —— 本仓库依赖的全部 Homebrew 包,一条命令装齐:
#
#   brew bundle --file=Brewfile
#
# Then: bash terminal/install.sh  (configs + gtmux + the rest)
# 然后: bash terminal/install.sh(配置 + gtmux + 其余设置)
# ============================================================================

# ---- Terminal environment (required by terminal/) / 终端环境(必需) --------
cask "ghostty"      # the terminal (>= 1.3 for gtmux restore/focus) | 终端本体
brew "tmux"         # session persistence (>= 3.3 for allow-passthrough) | 会话持久化
brew "ncurses"      # tmux-256color terminfo (colors/keys inside tmux) | tmux 内颜色/按键

# ---- Browsing code in the terminal (optional) / 终端里翻代码(可选) --------
# See README "Browsing code in the terminal" | 见 README「在终端里浏览代码」
brew "eza"          # tree / better ls | 目录树
brew "bat"          # view files with highlighting | 带高亮看文件
brew "ripgrep"      # fast search | 快速搜索
brew "fzf"          # fuzzy jump | 模糊跳转
brew "lazygit"      # git TUI
brew "yazi"         # file manager | 文件管理器

# ---- Deliberately NOT here / 有意不放进来的 --------------------------------
# gtmux: terminal/install.sh installs it (prebuilt binary, CN-mirror fallback).
#   Homebrew alternative: brew install chenchaoyi/tap/gtmux
#                         brew install --cask chenchaoyi/tap/gtmux-app
# gtmux: 由 terminal/install.sh 安装(预编译二进制,含国内镜像回退);
#   也可用上面的 Homebrew tap 方式安装。
# cloudflared: only needed for `gtmux tunnel` (remote phone access);
#   gtmux offers to install it when you first need it.
# cloudflared: 仅 `gtmux tunnel`(手机远程)需要;首次用到时 gtmux 会主动询问安装。
