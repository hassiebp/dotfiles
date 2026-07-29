#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup"

# Detect OS
case "$(uname)" in
Darwin) OS="macos" ;;
Linux) OS="linux" ;;
*)
  echo "Unsupported OS"
  exit 1
  ;;
esac

link_file() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"

  # Skip if symlink already points to correct location
  if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
    echo "  ✓ $dest"
    return 0
  fi

  # Backup existing file/symlink
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$dest").$(date +%Y%m%d_%H%M%S)"
    mv "$dest" "$BACKUP_DIR/$backup_name"
    echo "  ⚠ Backed up: $dest"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  → $dest"
}

echo "Setting up dotfiles for $OS..."

# Shared symlinks
link_file "shared/git/gitconfig" "$HOME/.gitconfig"
link_file "shared/tmux/tmux.conf" "$HOME/.tmux.conf"
link_file "shared/nvim" "$HOME/.config/nvim"
link_file "shared/pgcli" "$HOME/.config/pgcli"
link_file "shared/claude/settings.json" "$HOME/.claude/settings.json"
link_file "shared/claude/statusline.sh" "$HOME/.claude/statusline.sh"
link_file "shared/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
link_file "shared/agents/skills" "$HOME/.agents/skills"

# OS-specific symlinks
case "$OS" in
macos)
  link_file "macos/zshrc" "$HOME/.zshrc"
  link_file "macos/ghostty" "$HOME/.config/ghostty"
  link_file "macos/linear/coding-tools.json" "$HOME/.linear/coding-tools.json"
  link_file "macos/linear/linear-codex-investigate" "$HOME/.local/bin/linear-codex-investigate"
  link_file "shared/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
  link_file "shared/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
  ;;
linux)
  link_file "linux/zshrc" "$HOME/.zshrc"
  link_file "shared/vscode/settings.json" "$HOME/.config/Code/User/settings.json"
  link_file "shared/vscode/keybindings.json" "$HOME/.config/Code/User/keybindings.json"
  ;;
esac

echo "Done!"
