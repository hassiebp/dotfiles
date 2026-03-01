#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/setup-common.sh"

SC_SCRIPT_NAME="$SCRIPT_NAME"
sc_require_bash5
sc_init_cleanup_trap

CONFIG_FILE="$SCRIPT_DIR/config/vps.env"
for ((i = 1; i <= $#; i++)); do
  if [[ "${!i}" == "--config" ]]; then
    next=$((i + 1))
    [[ $next -le $# ]] || sc_die "--config requires a file path"
    CONFIG_FILE="${!next}"
    break
  fi
done
sc_load_config_file "$CONFIG_FILE"

SC_MODE="${VPS_MODE:-latest}"
SC_DRY_RUN=0
SC_VERBOSE=0
SC_ASSUME_YES=0
SC_FORCE=0
SC_USE_STATE="${VPS_USE_STATE:-1}"
SC_RETRY_ATTEMPTS="${VPS_RETRY_ATTEMPTS:-3}"
SC_RETRY_DELAY_SECONDS="${VPS_RETRY_DELAY_SECONDS:-2}"
SC_LOG_FILE="${VPS_LOG_FILE:-$HOME/.local/state/setup-vps/setup.log}"
SC_STATE_DIR="${VPS_STATE_DIR:-$HOME/.local/state/setup-vps/phase-state}"

SSH_PORT="${VPS_DEFAULT_SSH_PORT:-22}"
TARGET_USER=""
TARGET_HOME=""
SSH_PUBLIC_KEY=""
SSH_KEY_FILE=""
LOCAL_KEY_PATH="~/.ssh/id_ed25519.pub"
BOOTSTRAP_USER="root"
SERVER_ADDRESS=""
HOSTNAME_VALUE=""
TIMEZONE=""
PACKAGES_OVERRIDE=""
DOTFILES_REPO=""

WITH_UFW="${VPS_USE_UFW:-1}"
WITH_UNATTENDED_UPGRADES="${VPS_USE_UNATTENDED_UPGRADES:-1}"
WITH_FAIL2BAN="${VPS_USE_FAIL2BAN:-0}"
DISABLE_ROOT_SSH="${VPS_DISABLE_ROOT_SSH:-1}"
DISABLE_PASSWORD_AUTH="${VPS_DISABLE_PASSWORD_AUTH:-1}"
RUN_DOTFILES="${VPS_RUN_DOTFILES:-1}"

MIN_NEOVIM_VERSION="${VPS_MIN_NEOVIM_VERSION:-0.11.0}"
PINNED_NEOVIM_TAG="${VPS_PINNED_NEOVIM_TAG:-v0.11.0}"
OH_MY_ZSH_REF="${VPS_OH_MY_ZSH_REF:-master}"

DEFAULT_PACKAGES=()
sc_parse_csv_to_array "${VPS_DEFAULT_PACKAGES:-zsh git curl tmux ripgrep fd-find bat fzf zoxide htop}" DEFAULT_PACKAGES
INSTALL_PACKAGES=()
SSH_KEYS=()
ONLY_PHASES=()
SKIP_PHASES=()
CUSTOM_PACKAGE_LIST=0

PHASE_ORDER=(precheck system user ssh_keys firewall ssh_config packages shell dotfiles verify)

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [options]

Bootstrap an Ubuntu VPS with minimal hardening and developer tooling.

Required:
  --username USER                 Non-root user to create/configure
  --ssh-key-file PATH             Path to SSH public key file on server
    or
  --ssh-public-key KEY            SSH public key string

Core options:
  --mode MODE                     latest|frozen (default: $SC_MODE)
  --frozen                        Shortcut for --mode frozen
  --config PATH                   Load config file (default: $CONFIG_FILE)
  --log-file PATH                 Log file path (default: $SC_LOG_FILE)
  --state-dir PATH                Phase state dir (default: $SC_STATE_DIR)
  --no-state                      Disable phase state markers
  --force                         Ignore completed phase markers
  --reset-state                   Delete state markers before run

Setup options:
  --ssh-port PORT                 SSH port (default: $SSH_PORT)
  --local-key-path PATH           Local public key path shown in scp hint
  --bootstrap-user USER           SSH user shown in scp hint (default: root)
  --server-address HOST           Server address shown in scp hint
  --hostname NAME                 Set system hostname
  --timezone TZ                   Set timezone (e.g. UTC, Europe/Berlin)
  --install-packages CSV          Override package list (comma-separated)
  --dotfiles-repo URL             Clone/pull repo for target user, then run install.sh
  --no-dotfiles                   Skip dotfiles phase
  --without-ufw                   Skip UFW setup
  --without-unattended-upgrades   Skip unattended security upgrades
  --with-fail2ban                 Install and enable fail2ban
  --keep-root-ssh                 Keep root SSH login enabled
  --keep-password-auth            Keep SSH password auth enabled

Execution control:
  --only CSV                      Run only selected phases
  --skip CSV                      Skip selected phases
  --dry-run                       Print actions without executing
  --yes                           Non-interactive mode
  --verbose                       Print executed commands
  -h, --help                      Show this help

Phases:
  ${PHASE_ORDER[*]}
USAGE
}

validate_mode() {
  [[ "$SC_MODE" == "latest" || "$SC_MODE" == "frozen" ]] || sc_die "Invalid mode '$SC_MODE'. Use latest or frozen."
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  ((port >= 1 && port <= 65535))
}

resolve_target_home() {
  local entry
  entry="$(getent passwd "$TARGET_USER" || true)"
  [[ -n "$entry" ]] || sc_die "Could not resolve user '$TARGET_USER'."
  TARGET_HOME="$(printf '%s' "$entry" | cut -d: -f6)"
  [[ -n "$TARGET_HOME" ]] || sc_die "Could not resolve home directory for '$TARGET_USER'."
}

detect_server_address() {
  if [[ -n "$SERVER_ADDRESS" ]]; then
    return
  fi

  local detected=""
  detected="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  if [[ -n "$detected" ]]; then
    SERVER_ADDRESS="$detected"
  else
    SERVER_ADDRESS="<server-ip>"
  fi
}

prompt_for_local_key_copy_if_missing() {
  [[ -n "$SSH_KEY_FILE" ]] || return 0
  [[ -f "$SSH_KEY_FILE" ]] && return

  detect_server_address
  sc_warn "SSH key file not found on server: $SSH_KEY_FILE"
  sc_warn "From your local machine, run:"
  sc_warn "  scp $LOCAL_KEY_PATH ${BOOTSTRAP_USER}@${SERVER_ADDRESS}:$SSH_KEY_FILE"

  if ((SC_DRY_RUN)); then
    sc_warn "Dry-run mode: skipping wait for local copy."
    return
  fi

  if ((SC_ASSUME_YES)); then
    sc_die "Cannot continue with --yes until '$SSH_KEY_FILE' exists on the server."
  fi

  while true; do
    local answer=""
    read -r -p "Type 'yes' after running the scp command: " answer
    [[ "$answer" == "yes" ]] || { sc_warn "Type 'yes' to continue."; continue; }
    [[ -f "$SSH_KEY_FILE" ]] && break
    sc_warn "File still not found at '$SSH_KEY_FILE'."
  done
}

load_ssh_keys() {
  SSH_KEYS=()

  if [[ -n "$SSH_KEY_FILE" ]]; then
    [[ -f "$SSH_KEY_FILE" ]] || sc_die "SSH key file not found: $SSH_KEY_FILE"
    mapfile -t SSH_KEYS < <(grep -Ev '^[[:space:]]*($|#)' "$SSH_KEY_FILE")
  fi

  if [[ -n "$SSH_PUBLIC_KEY" ]]; then
    SSH_KEYS+=("$SSH_PUBLIC_KEY")
  fi

  if sc_should_run_phase ssh_keys ONLY_PHASES SKIP_PHASES && ((${#SSH_KEYS[@]} == 0)); then
    sc_die "No usable SSH keys found."
  fi
}

apt_update_cmd() {
  sc_run_sudo apt-get -o DPkg::Lock::Timeout=120 update
}

apt_upgrade_cmd() {
  sc_run_sudo env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 -y upgrade
}

apt_install_cmd() {
  sc_run_sudo env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 install -y "$@"
}

apt_update() {
  sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" apt_update_cmd
}

apt_upgrade() {
  sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" apt_upgrade_cmd
}

apt_install() {
  local pkgs=("$@")
  ((${#pkgs[@]} > 0)) || return
  sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" apt_install_cmd "${pkgs[@]}"
}

download_file() {
  local url="$1"
  local dest="$2"
  sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_sudo curl -fL "$url" -o "$dest"
}

verify_neovim_archive() {
  local archive="$1"
  local sha_file="$2"
  local asset_name="$3"

  local expected actual
  expected="$(awk -v asset="$asset_name" '$0 ~ asset {print $1; exit}' "$sha_file")"
  [[ -n "$expected" ]] || sc_die "Could not find checksum for $asset_name"

  actual="$(sha256sum "$archive" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || sc_die "Checksum mismatch for Neovim archive"
}

phase_preflight() {
  local phase="$1"
  case "$phase" in
    precheck) sc_require_commands apt-get systemctl getent || return 1 ;;
    system) sc_require_commands hostnamectl timedatectl || return 1 ;;
    user) sc_require_commands adduser usermod || return 1 ;;
    ssh_keys) sc_require_commands install grep tee || return 1 ;;
    ssh_config) sc_require_commands sshd || return 1 ;;
    firewall) sc_require_commands ufw || true ;;
    packages) sc_require_commands curl tar sha256sum || return 1 ;;
    shell) sc_require_commands git zsh || true ;;
    dotfiles) sc_require_commands git || return 1 ;;
    verify) sc_require_commands sshd systemctl || return 1 ;;
  esac
}

phase_precheck() {
  sc_assert_ubuntu

  if ((EUID != 0)) && ! command -v sudo >/dev/null 2>&1; then
    sc_die "sudo is required when not running as root."
  fi

  [[ -n "$TARGET_USER" ]] || sc_die "--username is required."
  [[ "$TARGET_USER" != "root" ]] || sc_die "--username must be a non-root user."

  if ! sc_should_run_phase user ONLY_PHASES SKIP_PHASES && ! id -u "$TARGET_USER" >/dev/null 2>&1; then
    sc_die "User '$TARGET_USER' does not exist and user phase is skipped."
  fi

  if [[ -z "$SSH_KEY_FILE" && -z "$SSH_PUBLIC_KEY" ]] && sc_should_run_phase ssh_keys ONLY_PHASES SKIP_PHASES; then
    sc_die "Provide --ssh-key-file or --ssh-public-key."
  fi

  validate_port "$SSH_PORT" || sc_die "Invalid --ssh-port '$SSH_PORT'."

  prompt_for_local_key_copy_if_missing
  load_ssh_keys

  sc_info "Configuration summary:"
  sc_info "  mode=$SC_MODE"
  sc_info "  user=$TARGET_USER"
  sc_info "  ssh_port=$SSH_PORT"
  sc_info "  dry_run=$SC_DRY_RUN"
  sc_info "  log_file=$SC_LOG_FILE"
  sc_info "  state_dir=$SC_STATE_DIR"

  sc_confirm_or_exit "Proceed with VPS setup"
}

phase_system() {
  apt_update

  if [[ "$SC_MODE" == "latest" ]]; then
    apt_upgrade
  else
    sc_info "Frozen mode: skipping apt upgrade"
  fi

  local sys_pkgs=()
  if sc_should_run_phase ssh_config ONLY_PHASES SKIP_PHASES; then
    sys_pkgs+=(openssh-server)
  fi
  if ((WITH_UNATTENDED_UPGRADES)); then
    sys_pkgs+=(unattended-upgrades apt-listchanges)
  fi
  if ((WITH_FAIL2BAN)); then
    sys_pkgs+=(fail2ban)
  fi
  apt_install "${sys_pkgs[@]}"

  if [[ -n "$HOSTNAME_VALUE" ]]; then
    sc_run_sudo hostnamectl set-hostname "$HOSTNAME_VALUE"
  fi

  if [[ -n "$TIMEZONE" ]]; then
    sc_run_sudo timedatectl set-timezone "$TIMEZONE"
  fi

  if ((WITH_UNATTENDED_UPGRADES)); then
    local auto_file
    auto_file="$(mktemp)"
    sc_register_tmp_path "$auto_file"
    cat > "$auto_file" <<'AUTOUNATTENDED'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AUTOUNATTENDED
    sc_run_sudo install -m 644 "$auto_file" /etc/apt/apt.conf.d/20auto-upgrades
    sc_run_sudo dpkg-reconfigure -f noninteractive unattended-upgrades
  fi

  if ((WITH_FAIL2BAN)); then
    sc_run_sudo systemctl enable --now fail2ban
  fi
}

phase_user() {
  if id -u "$TARGET_USER" >/dev/null 2>&1; then
    sc_info "User '$TARGET_USER' already exists"
  else
    sc_run_sudo adduser --disabled-password --gecos "" "$TARGET_USER"
  fi

  sc_run_sudo usermod -aG sudo "$TARGET_USER"
  resolve_target_home
}

phase_ssh_keys() {
  resolve_target_home

  local ssh_dir="$TARGET_HOME/.ssh"
  local auth_keys_file="$ssh_dir/authorized_keys"

  sc_run_sudo install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$ssh_dir"
  sc_run_sudo touch "$auth_keys_file"
  sc_run_sudo chown "$TARGET_USER:$TARGET_USER" "$auth_keys_file"
  sc_run_sudo chmod 600 "$auth_keys_file"

  local key
  for key in "${SSH_KEYS[@]}"; do
    if sc_run_sudo grep -Fqx "$key" "$auth_keys_file"; then
      sc_info "SSH key already present"
    else
      printf '%s\n' "$key" | sc_run_sudo tee -a "$auth_keys_file" >/dev/null
      sc_info "Added SSH key"
    fi
  done
}

phase_ssh_config() {
  resolve_target_home

  local auth_keys_file="$TARGET_HOME/.ssh/authorized_keys"
  if ((DISABLE_PASSWORD_AUTH || DISABLE_ROOT_SSH)); then
    [[ -s "$auth_keys_file" ]] || sc_die "Refusing to harden SSH without authorized_keys for $TARGET_USER"
  fi

  local main_config="/etc/ssh/sshd_config"
  local include_line='Include /etc/ssh/sshd_config.d/*.conf'

  if ! sc_run_sudo grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$main_config"; then
    sc_run_sudo bash -lc "printf '\n%s\n' '$include_line' >> '$main_config'"
  fi

  local dropin
  dropin="$(mktemp)"
  sc_register_tmp_path "$dropin"

  {
    echo "# Managed by $SCRIPT_NAME"
    echo "Port $SSH_PORT"
    if ((DISABLE_ROOT_SSH)); then
      echo "PermitRootLogin no"
    else
      echo "PermitRootLogin yes"
    fi
    if ((DISABLE_PASSWORD_AUTH)); then
      echo "PasswordAuthentication no"
      echo "KbdInteractiveAuthentication no"
      echo "ChallengeResponseAuthentication no"
    else
      echo "PasswordAuthentication yes"
    fi
    echo "PubkeyAuthentication yes"
    echo "UsePAM yes"
  } > "$dropin"

  sc_run_sudo install -d -m 755 /etc/ssh/sshd_config.d
  sc_run_sudo install -m 644 "$dropin" /etc/ssh/sshd_config.d/99-vps-setup.conf

  sc_run_sudo sshd -t

  if sc_run_sudo systemctl reload ssh; then
    :
  elif sc_run_sudo systemctl reload sshd; then
    :
  else
    sc_die "Failed to reload SSH service"
  fi
}

phase_firewall() {
  if ((WITH_UFW == 0)); then
    sc_info "Skipping UFW configuration"
    return
  fi

  apt_install ufw

  local current_port="22"
  current_port="$(sc_run_sudo sshd -T 2>/dev/null | awk '/^port /{print $2; exit}' || echo 22)"

  sc_run_sudo ufw default deny incoming
  sc_run_sudo ufw default allow outgoing
  if [[ "$current_port" != "$SSH_PORT" ]]; then
    sc_run_sudo ufw allow "${current_port}/tcp"
  fi
  sc_run_sudo ufw allow "${SSH_PORT}/tcp"
  sc_run_sudo ufw --force enable
}

phase_packages() {
  local pkgs=(ca-certificates curl tar "${INSTALL_PACKAGES[@]}")
  apt_install "${pkgs[@]}"

  local arch asset base_url tag nvim_tmp_dir archive checksum nvim_cmd
  local skip_nvim_install=0
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) sc_die "Unsupported architecture: $(uname -m)" ;;
  esac

  asset="nvim-linux-${arch}.tar.gz"
  if [[ "$SC_MODE" == "latest" ]]; then
    base_url="https://github.com/neovim/neovim/releases/latest/download"
    tag="latest"
  else
    tag="$PINNED_NEOVIM_TAG"
    base_url="https://github.com/neovim/neovim/releases/download/${tag}"
  fi

  if [[ "$SC_MODE" == "frozen" ]] && command -v nvim >/dev/null 2>&1; then
    local current
    current="$(nvim --version | awk 'NR==1 {print $2}' | sed 's/^v//')"
    if [[ -n "$current" && "$(printf '%s\n%s\n' "$current" "$MIN_NEOVIM_VERSION" | sort -V | head -n1)" == "$MIN_NEOVIM_VERSION" ]]; then
      sc_info "Frozen mode: keeping existing Neovim $current"
      skip_nvim_install=1
    fi
  fi

  if ((skip_nvim_install == 0)); then
    nvim_tmp_dir="$(mktemp -d)"
    sc_register_tmp_path "$nvim_tmp_dir"
    archive="$nvim_tmp_dir/$asset"
    checksum="$nvim_tmp_dir/$asset.sha256sum"

    download_file "$base_url/$asset" "$archive"
    download_file "$base_url/$asset.sha256sum" "$checksum"
    verify_neovim_archive "$archive" "$checksum" "$asset"

    sc_run_sudo rm -rf /opt/nvim
    sc_run_sudo install -d -m 755 /opt/nvim
    sc_run_sudo tar -xzf "$archive" -C /opt/nvim --strip-components=1
    sc_run_sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
    sc_run_sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/vim
  fi

  nvim_cmd="$(command -v nvim || true)"
  [[ -x "$nvim_cmd" ]] || sc_die "Failed to locate Neovim binary after setup"

  local installed_nvim_version
  installed_nvim_version="$("$nvim_cmd" --version | awk 'NR==1 {print $2}' | sed 's/^v//')"
  [[ -n "$installed_nvim_version" ]] || sc_die "Failed to detect installed Neovim version"
  [[ "$(printf '%s\n%s\n' "$installed_nvim_version" "$MIN_NEOVIM_VERSION" | sort -V | head -n1)" == "$MIN_NEOVIM_VERSION" ]] || sc_die "Neovim $installed_nvim_version is below required $MIN_NEOVIM_VERSION"

  if ((CUSTOM_PACKAGE_LIST == 0)); then
    if ! apt_install eza; then
      sc_warn "eza unavailable, trying exa"
      apt_install exa || sc_warn "Could not install eza/exa"
    fi
  fi

  if ! command -v bat >/dev/null 2>&1 && [[ -x /usr/bin/batcat ]]; then
    sc_run_sudo install -d -m 755 /usr/local/bin
    sc_run_sudo ln -sfn /usr/bin/batcat /usr/local/bin/bat
  fi

  if ! command -v fd >/dev/null 2>&1 && [[ -x /usr/bin/fdfind ]]; then
    sc_run_sudo install -d -m 755 /usr/local/bin
    sc_run_sudo ln -sfn /usr/bin/fdfind /usr/local/bin/fd
  fi

  sc_add_summary "Neovim version: $installed_nvim_version (source: $tag)"
}

phase_shell() {
  resolve_target_home

  apt_install zsh git

  local ohmyzsh_dir="$TARGET_HOME/.oh-my-zsh"
  local ohmyzsh_ref="$OH_MY_ZSH_REF"
  if [[ "$SC_MODE" == "frozen" && "$ohmyzsh_ref" == "master" && ! -d "$ohmyzsh_dir/.git" ]]; then
    sc_die "Frozen mode requires VPS_OH_MY_ZSH_REF to be pinned (tag or commit), not 'master'."
  fi
  if [[ -d "$ohmyzsh_dir/.git" ]]; then
    if [[ "$SC_MODE" == "latest" ]]; then
      sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_as_user_cmd "$TARGET_USER" git -C "$ohmyzsh_dir" pull --ff-only
    else
      sc_info "Frozen mode: skipping oh-my-zsh update"
    fi
  else
    sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_as_user_cmd "$TARGET_USER" git clone --depth 1 --branch "$ohmyzsh_ref" https://github.com/ohmyzsh/ohmyzsh.git "$ohmyzsh_dir"
  fi

  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [[ -n "$zsh_path" ]] || sc_die "zsh is not installed"
  sc_run_sudo usermod -s "$zsh_path" "$TARGET_USER"
}

phase_dotfiles() {
  if ((RUN_DOTFILES == 0)); then
    sc_info "Skipping dotfiles phase"
    return
  fi

  resolve_target_home

  local install_dir="$DOTFILES_DIR"
  if [[ -n "$DOTFILES_REPO" ]]; then
    install_dir="$TARGET_HOME/dotfiles"
    if [[ -d "$install_dir/.git" ]]; then
      if [[ "$SC_MODE" == "latest" ]]; then
        sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_as_user_cmd "$TARGET_USER" git -C "$install_dir" pull --ff-only
      else
        sc_info "Frozen mode: skipping dotfiles pull"
      fi
    else
      sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_as_user_cmd "$TARGET_USER" git clone "$DOTFILES_REPO" "$install_dir"
    fi
  fi

  if sc_run_as_user_cmd "$TARGET_USER" test -x "$install_dir/install.sh"; then
    local q_install_dir
    q_install_dir="$(sc_quote "$install_dir")"
    sc_run_as_user "$TARGET_USER" "cd $q_install_dir && ./install.sh"
  else
    sc_warn "Skipping dotfiles: '$install_dir/install.sh' not executable for '$TARGET_USER'"
  fi
}

phase_verify() {
  resolve_target_home

  sc_run_sudo sshd -t

  local ssh_status="inactive"
  if sc_run_sudo systemctl is-active --quiet ssh; then
    ssh_status="active(ssh)"
  elif sc_run_sudo systemctl is-active --quiet sshd; then
    ssh_status="active(sshd)"
  fi

  local ufw_status="disabled"
  if ((WITH_UFW)); then
    ufw_status="$(sc_run_sudo ufw status | head -n1 | sed 's/^Status: //')"
  fi

  local nvim_version="missing"
  if command -v nvim >/dev/null 2>&1; then
    nvim_version="$(nvim --version | awk 'NR==1 {print $2}')"
  fi

  local shell_value
  shell_value="$(getent passwd "$TARGET_USER" | cut -d: -f7)"

  sc_add_summary "SSH service: $ssh_status"
  sc_add_summary "UFW status: $ufw_status"
  sc_add_summary "Neovim: $nvim_version"
  sc_add_summary "User shell: $shell_value"
  sc_add_summary "Verify login command: ssh -p $SSH_PORT $TARGET_USER@<server-ip>"
}

run_phase() {
  local phase="$1"

  if ! sc_should_run_phase "$phase" ONLY_PHASES SKIP_PHASES; then
    sc_info "Skipping phase: $phase"
    return
  fi

  if sc_maybe_skip_phase_for_state "$phase"; then
    sc_info "Skipping phase: $phase (already completed)"
    return
  fi

  phase_preflight "$phase" || sc_die "Preflight failed for phase '$phase'"

  sc_info "=== Phase: $phase ==="
  "phase_${phase}"
  sc_mark_phase_done "$phase"
}

parse_args() {
  local reset_state=0

  while (($# > 0)); do
    case "$1" in
      --config)
        [[ -n "${2:-}" ]] || sc_die "--config requires a file path"
        shift 2
        ;;
      --username)
        TARGET_USER="${2:-}"
        shift 2
        ;;
      --ssh-key-file)
        SSH_KEY_FILE="${2:-}"
        shift 2
        ;;
      --ssh-public-key)
        SSH_PUBLIC_KEY="${2:-}"
        shift 2
        ;;
      --ssh-port)
        SSH_PORT="${2:-}"
        shift 2
        ;;
      --local-key-path)
        LOCAL_KEY_PATH="${2:-}"
        shift 2
        ;;
      --bootstrap-user)
        BOOTSTRAP_USER="${2:-}"
        shift 2
        ;;
      --server-address)
        SERVER_ADDRESS="${2:-}"
        shift 2
        ;;
      --hostname)
        HOSTNAME_VALUE="${2:-}"
        shift 2
        ;;
      --timezone)
        TIMEZONE="${2:-}"
        shift 2
        ;;
      --install-packages)
        PACKAGES_OVERRIDE="${2:-}"
        CUSTOM_PACKAGE_LIST=1
        shift 2
        ;;
      --dotfiles-repo)
        DOTFILES_REPO="${2:-}"
        shift 2
        ;;
      --mode)
        SC_MODE="${2:-}"
        shift 2
        ;;
      --frozen)
        SC_MODE="frozen"
        shift
        ;;
      --log-file)
        SC_LOG_FILE="${2:-}"
        shift 2
        ;;
      --state-dir)
        SC_STATE_DIR="${2:-}"
        shift 2
        ;;
      --no-state)
        SC_USE_STATE=0
        shift
        ;;
      --force)
        SC_FORCE=1
        shift
        ;;
      --reset-state)
        reset_state=1
        shift
        ;;
      --only)
        sc_parse_csv_to_array "${2:-}" ONLY_PHASES
        shift 2
        ;;
      --skip)
        sc_parse_csv_to_array "${2:-}" SKIP_PHASES
        shift 2
        ;;
      --no-dotfiles)
        RUN_DOTFILES=0
        shift
        ;;
      --without-ufw)
        WITH_UFW=0
        shift
        ;;
      --without-unattended-upgrades)
        WITH_UNATTENDED_UPGRADES=0
        shift
        ;;
      --with-fail2ban)
        WITH_FAIL2BAN=1
        shift
        ;;
      --keep-root-ssh)
        DISABLE_ROOT_SSH=0
        shift
        ;;
      --keep-password-auth)
        DISABLE_PASSWORD_AUTH=0
        shift
        ;;
      --dry-run)
        SC_DRY_RUN=1
        shift
        ;;
      --yes)
        SC_ASSUME_YES=1
        shift
        ;;
      --verbose)
        SC_VERBOSE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        sc_die "Unknown option: $1"
        ;;
    esac
  done

  validate_mode
  sc_validate_phase_list ONLY_PHASES PHASE_ORDER
  sc_validate_phase_list SKIP_PHASES PHASE_ORDER

  if ((${#ONLY_PHASES[@]} > 0)) && ((${#SKIP_PHASES[@]} > 0)); then
    local phase
    for phase in "${SKIP_PHASES[@]}"; do
      if sc_contains "$phase" "${ONLY_PHASES[@]}"; then
        sc_die "Phase '$phase' is present in both --only and --skip."
      fi
    done
  fi

  if [[ -n "$PACKAGES_OVERRIDE" ]]; then
    sc_parse_csv_to_array "$PACKAGES_OVERRIDE" INSTALL_PACKAGES
  else
    INSTALL_PACKAGES=("${DEFAULT_PACKAGES[@]}")
  fi

  ((CUSTOM_PACKAGE_LIST == 0)) || ((${#INSTALL_PACKAGES[@]} > 0)) || sc_die "No packages parsed from --install-packages"

  sc_init_log_file "$SC_LOG_FILE"
  if ((reset_state)); then
    sc_reset_state_dir
  fi
  sc_prepare_state_dir
}

main() {
  parse_args "$@"

  local phase
  for phase in "${PHASE_ORDER[@]}"; do
    run_phase "$phase"
  done

  sc_info "Setup complete."
  sc_print_summary
}

main "$@"
