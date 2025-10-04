# Hassieb's dotfiles

This repository contains my personal configuration files (dotfiles) for various tools and applications, such as `zsh`, `tmux`, `git`, `neovim`, and `pgcli`. These dotfiles are managed in a version-controlled repository to easily sync configurations across multiple machines.

## Installation

To set up these dotfiles on a new machine, you can use the provided `install.sh` script. This script will create symbolic links from your home directory to the version-controlled files in this repository.

### Prerequisites

Before installing, make sure you have the following installed:

- **zsh** - Shell
- **tmux** - Terminal multiplexer
- **neovim** - Text editor
- **pgcli** - PostgreSQL client (optional, if you use Postgres)
- **git** - Version control
- **oh-my-zsh** - Zsh framework

### Quick Start

```bash
git clone https://github.com/hassiebp/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script will:

- Detect your OS (macOS or Linux) and configure accordingly
- Back up any existing dotfiles to `~/.dotfiles_backup` with timestamps
- Create symbolic links from the dotfiles in this repository to their appropriate locations
- Skip files that are already correctly linked (safe to re-run)

## What's Included

### Shared Configurations

- **git** - Git configuration and aliases
- **tmux** - Terminal multiplexer configuration
- **nvim** - Neovim configuration (LazyVim-based)
- **pgcli** - PostgreSQL CLI with smart completion (vi mode enabled)

### Platform-Specific

- **macOS**: zsh configuration, ghostty (terminal emulator)
- **Linux**: zsh configuration

## How It Works

This dotfiles setup uses **symbolic links** to connect your version-controlled config files to the locations where applications expect them. For example:

```
~/.gitconfig -> ~/dotfiles/shared/git/gitconfig
~/.tmux.conf -> ~/dotfiles/shared/tmux/tmux.conf
```

This means you can edit files in the `dotfiles` directory, commit changes, and they immediately take effect in your applications.

## Local Overrides

For machine-specific configurations that shouldn't be version controlled:

### Shell Configuration (`.zshrc.local`)
Create `~/.zshrc.local` to add machine-specific settings:
```bash
# Example ~/.zshrc.local
export PATH="/custom/path:$PATH"
alias work="cd ~/my-work-dir"
```

This file is automatically sourced at the end of your shell configuration.

### Tmux Projects (`.tmux-projects.conf`)
Create `~/.tmux-projects.conf` to customize project directories for tmux session management:
```bash
# Example ~/.tmux-projects.conf
export TMUX_PROJECT_DIRS="~/projects ~/work ~/dev"
```

### Git Configuration
To override the git user email/name for specific machines, use `.zshrc.local`:
```bash
git config --global user.email "your.email@example.com"
git config --global user.name "Your Name"
```

## Troubleshooting

**Q: Installation fails with "command not found"**
A: Make sure all prerequisites are installed. The script requires `zsh`, `oh-my-zsh`, and other tools listed in the Prerequisites section.

**Q: My configs aren't taking effect**
A: Restart your shell or source the config: `source ~/.zshrc`

**Q: I want to undo the installation**
A: Your original configs are backed up in `~/.dotfiles_backup/`. Remove the symlinks and restore from there.

**Q: Can I use these dotfiles on multiple machines?**
A: Yes! That's the whole point. Use `.zshrc.local` for machine-specific differences.
