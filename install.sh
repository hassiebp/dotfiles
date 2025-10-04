#!/bin/zsh

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup"

setup_environment() {
   case "$(uname)" in
       "Darwin")
           OS="macos"
           ;;
       "Linux")
           OS="linux"
           ;;
   esac
}

get_symlinks() {
   typeset -A links=(
       "shared/git/gitconfig" "$HOME/.gitconfig"
       "shared/tmux/tmux.conf" "$HOME/.tmux.conf"
       "shared/nvim" "$HOME/.config/nvim"
       "shared/pgcli" "$HOME/.config/pgcli"
   )

   case "$OS" in
       "macos")
           links+=(
               "macos/zshrc" "$HOME/.zshrc"
               "macos/ghostty" "$HOME/.config/ghostty"
           )
           ;;
       "linux")
           links+=("linux/zshrc" "$HOME/.zshrc")
           ;;
   esac

   echo ${(kv)links}
}

link_file() {
   local src="$DOTFILES_DIR/$1" dest="$2"

   # Skip if symlink already points to correct location
   if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
       echo "✓ Already linked: $dest"
       return 0
   fi

   # Backup existing file/symlink if it exists
   if [[ -e "$dest" || -L "$dest" ]]; then
       mkdir -p "$BACKUP_DIR"
       local backup_name="$(basename "$dest").$(date +%Y%m%d_%H%M%S)"
       mv "$dest" "$BACKUP_DIR/$backup_name"
       echo "Backed up $dest to $BACKUP_DIR/$backup_name"
   fi

   mkdir -p "$(dirname "$dest")"
   ln -s "$src" "$dest"
   echo "Linked $src -> $dest"
}


main() {
   echo "🤖 Setting up dotfiles..."
   setup_environment

   echo "🤖 Creating symlinks..."
   local symlinks=($(get_symlinks))
   for ((i=1; i <= ${#symlinks}; i+=2)); do
       link_file "${symlinks[i]}" "${symlinks[i+1]}"
   done

   echo "✅ Dotfiles installation complete!"
}

main
