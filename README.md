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

### Ubuntu VPS Bootstrap

For a fresh Ubuntu VPS, use the bootstrap script to harden SSH/firewall, set up your user, install tools, and verify health checks.

> Note: setup scripts require Bash 5+ (standard on modern Ubuntu).

```bash
cd ~/dotfiles
./linux/setup-vps.sh \
  --username hassieb \
  --ssh-key-file /tmp/mykey.pub \
  --ssh-port 22 \
  --yes
```

If the remote key file does not exist yet, the script pauses and asks you to run this from your local machine, then confirm:

```bash
scp ~/.ssh/id_ed25519.pub root@<server-ip>:/tmp/mykey.pub
```

Then continue in the same server terminal by typing `yes` when prompted.  
For a fully non-interactive run, copy the key first and then run:

```bash
./linux/setup-vps.sh \
  --username hassieb \
  --ssh-key-file /tmp/mykey.pub \
  --ssh-port 22 \
  --yes
```

Default behavior:

- Creates the target user (if missing) and adds it to `sudo`
- Adds your SSH public key to `~/.ssh/authorized_keys`
- Configures SSH to use port `22`, disable root login, and disable password auth
- Enables UFW (`deny incoming`, `allow outgoing`, `allow 22/tcp`)
- Enables unattended security upgrades
- Installs core CLI tooling (`zsh`, `bat`, `fd-find`, `ripgrep`, `fzf`, `zoxide`, `tmux`, `eza`/`exa`, etc.)
- Installs Neovim from official release tarballs with checksum verification (minimum `0.11.0`)
- Installs Oh My Zsh via git clone and sets `zsh` as default shell
- Runs `./install.sh` for dotfile symlinks when available to the target user
- Runs a final `verify` phase to report service/tool status

Useful flags:

- `--mode latest|frozen` latest updates vs reproducible frozen behavior
- `--dry-run` preview actions without changing the machine
- `--only precheck,system,packages` run selected phases only
- `--skip dotfiles` skip specific phases
- `--dotfiles-repo <url>` clone/pull dotfiles for the target user before running `install.sh`
- `--state-dir`, `--no-state`, `--force`, `--reset-state` control phase state markers
- `--local-key-path`, `--bootstrap-user`, `--server-address` customize the printed local `scp` hint

Config defaults live in:

- `linux/config/vps.env`

### Langfuse Agent Setup

For Langfuse engineering setup on a new Ubuntu VPS, use the dedicated script:

```bash
cd ~/dotfiles
./linux/setup-langfuse-agent.sh \
  --username hassieb \
  --workspace-dir ~/langfuse \
  --git-email hasibspot@placeholder.invalid \
  --yes \
  --run-main-dx
```

Default behavior:

- Clones/updates `langfuse`, `langfuse-python`, `langfuse-js`, `langfuse-docs`
- Installs shared prerequisites (Docker, build deps, migrate CLI, clickhouse client)
- Installs a single enforced toolchain for all repos: Node `24`, pnpm `9.5.0`
- Installs Python via `pyenv` (`3.14.x`) and Poetry
- Applies repo-specific setup steps from local contribution docs
- Configures scoped Git identity for the Langfuse workspace via `includeIf`
- Installs GitHub CLI (`gh`) and authenticates it for the target user
- Runs a final `verify` phase with version/repo checks

Useful flags:

- `--mode latest|frozen`
- `--run-main-dx` run `pnpm run dx` in main Langfuse repo
- `--github-host`, `--github-token`, `--github-token-file` control `gh` auth target and credentials
- `--only ...` / `--skip ...` phase targeting
- `--state-dir`, `--no-state`, `--force`, `--reset-state`

`gh` authentication token sources (priority order):
- `--github-token`
- `--github-token-file`
- `GH_TOKEN` / `GITHUB_TOKEN` environment variables

If no token source is provided, the script prompts interactively unless `--yes` is set.

Config defaults live in:

- `linux/config/langfuse-agent.env`

The base dotfiles installer will:

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
