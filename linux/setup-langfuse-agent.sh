#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/setup-common.sh"

SC_SCRIPT_NAME="$SCRIPT_NAME"
sc_require_bash5
sc_init_cleanup_trap

CONFIG_FILE="$SCRIPT_DIR/config/langfuse-agent.env"
for ((i = 1; i <= $#; i++)); do
  if [[ "${!i}" == "--config" ]]; then
    next=$((i + 1))
    [[ $next -le $# ]] || sc_die "--config requires a file path"
    CONFIG_FILE="${!next}"
    break
  fi
done
sc_load_config_file "$CONFIG_FILE"

SC_MODE="${LANGFUSE_MODE:-latest}"
SC_DRY_RUN=0
SC_VERBOSE=0
SC_ASSUME_YES=0
SC_FORCE=0
SC_USE_STATE="${LANGFUSE_USE_STATE:-1}"
SC_RETRY_ATTEMPTS="${LANGFUSE_RETRY_ATTEMPTS:-3}"
SC_RETRY_DELAY_SECONDS="${LANGFUSE_RETRY_DELAY_SECONDS:-2}"
SC_LOG_FILE="${LANGFUSE_LOG_FILE:-$HOME/.local/state/setup-langfuse-agent/setup.log}"
SC_STATE_DIR="${LANGFUSE_STATE_DIR:-$HOME/.local/state/setup-langfuse-agent/phase-state}"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=""
WORKSPACE_DIR=""
WORKSPACE_DIR_SET=0

NODE_VERSION="${LANGFUSE_NODE_VERSION:-24}"
PNPM_VERSION="${LANGFUSE_PNPM_VERSION:-9.5.0}"
PYTHON_VERSION_PREFIX="${LANGFUSE_PYTHON_PREFIX:-3.14}"
PINNED_PYTHON_VERSION="${LANGFUSE_PINNED_PYTHON_VERSION:-3.14.0}"
MIGRATE_VERSION="${LANGFUSE_MIGRATE_VERSION:-v4.18.3}"
MIGRATE_BUILD_TAGS="${LANGFUSE_MIGRATE_BUILD_TAGS:-clickhouse}"
GO_MIN_TOOLCHAIN="${LANGFUSE_GO_MIN_TOOLCHAIN:-1.24.0}"
CLICKHOUSE_APT_CHANNEL="${LANGFUSE_CLICKHOUSE_APT_CHANNEL:-stable}"

GIT_NAME="${LANGFUSE_GIT_NAME:-hassiebbot}"
GIT_EMAIL="${LANGFUSE_GIT_EMAIL:-264775091+hassiebbot@users.noreply.github.com}"
GITHUB_USER="${LANGFUSE_GITHUB_USER:-hassiebbot}"
GITHUB_HOST="${LANGFUSE_GITHUB_HOST:-github.com}"
GH_AUTH_TOKEN="${LANGFUSE_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
GH_AUTH_TOKEN_FILE="${LANGFUSE_GITHUB_TOKEN_FILE:-}"

RUN_MAIN_DX="${LANGFUSE_RUN_MAIN_DX:-0}"

PHASE_ORDER=(precheck system_packages github_cli clone_repos node_tooling docker_tooling python_tooling git_identity repo_dependencies bootstrap_main verify)
ONLY_PHASES=()
SKIP_PHASES=()

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [options]

Set up Langfuse engineering environment on Ubuntu VPS.

Core options:
  --config PATH                   Load config file (default: $CONFIG_FILE)
  --mode MODE                     latest|frozen (default: $SC_MODE)
  --frozen                        Shortcut for --mode frozen
  --log-file PATH                 Log file path (default: $SC_LOG_FILE)
  --state-dir PATH                Phase state dir (default: $SC_STATE_DIR)
  --no-state                      Disable phase state markers
  --force                         Ignore completed phase markers
  --reset-state                   Delete state markers before run

Setup options:
  --workspace-dir PATH            Workspace root (default: ~<user>/${LANGFUSE_WORKSPACE_SUBDIR:-langfuse})
  --username USER                 Linux user to own workspace
  --python-version-prefix X.Y     Python major.minor for pyenv (default: $PYTHON_VERSION_PREFIX)
  --run-main-dx                   Run 'pnpm run dx' in main repo

Identity options:
  --git-name NAME                 Scoped Git user.name for workspace (default: $GIT_NAME)
  --git-email EMAIL               Scoped Git user.email for workspace (default placeholder)
  --github-user USER              GitHub username hint (default: $GITHUB_USER)
  --github-host HOST              GitHub host for gh auth (default: $GITHUB_HOST)
  --github-token TOKEN            GitHub token for gh auth
  --github-token-file PATH        File containing GitHub token for gh auth

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

resolve_target_home() {
  local entry
  entry="$(getent passwd "$TARGET_USER" || true)"
  [[ -n "$entry" ]] || sc_die "Could not resolve user '$TARGET_USER'"
  TARGET_HOME="$(printf '%s' "$entry" | cut -d: -f6)"
  [[ -n "$TARGET_HOME" ]] || sc_die "Could not resolve home directory for '$TARGET_USER'"
}

run_with_user_env() {
  local command="$1"
  sc_run_as_user "$TARGET_USER" "set -euo pipefail; export NVM_DIR=\"\$HOME/.nvm\"; [[ -s \"\$NVM_DIR/nvm.sh\" ]] && . \"\$NVM_DIR/nvm.sh\"; export PYENV_ROOT=\"\$HOME/.pyenv\"; export PATH=\"\$PYENV_ROOT/bin:\$HOME/.local/bin:\$PATH\"; if command -v pyenv >/dev/null 2>&1; then eval \"\$(pyenv init -)\"; fi; $command"
}

run_node_repo_cmd() {
  local repo_dir="$1"
  local command="$2"
  local q_repo_dir q_node_version q_pnpm_version
  q_repo_dir="$(sc_quote "$repo_dir")"
  q_node_version="$(sc_quote "$NODE_VERSION")"
  q_pnpm_version="$(sc_quote "$PNPM_VERSION")"

  run_with_user_env "cd $q_repo_dir; nvm install $q_node_version; nvm use $q_node_version; corepack enable; corepack prepare pnpm@$q_pnpm_version --activate; $command"
}

apt_update_cmd() {
  sc_run_sudo apt-get -o DPkg::Lock::Timeout=120 update
}

apt_install_cmd() {
  sc_run_sudo env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 install -y "$@"
}

apt_update() {
  sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" apt_update_cmd
}

apt_install() {
  local pkgs=("$@")
  ((${#pkgs[@]} > 0)) || return
  sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" apt_install_cmd "${pkgs[@]}"
}

clone_or_update_repo() {
  local repo_url="$1"
  local target_dir="$2"
  local name
  name="$(basename "$target_dir")"

  if [[ -d "$target_dir/.git" ]]; then
    if [[ "$SC_MODE" == "latest" ]]; then
      sc_info "Updating $name"
      if ! sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_as_user_cmd "$TARGET_USER" git -C "$target_dir" pull --ff-only; then
        sc_warn "Could not fast-forward $name. Keeping current checkout."
      fi
    else
      sc_info "Frozen mode: keeping existing $name checkout"
    fi
  else
    local parent_dir
    parent_dir="$(dirname "$target_dir")"
    sc_info "Cloning $name"
    sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_as_user_cmd "$TARGET_USER" mkdir -p "$parent_dir"
    sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_as_user_cmd "$TARGET_USER" git clone "$repo_url" "$target_dir"
  fi
}

load_gh_auth_token() {
  local token=""

  if [[ -n "$GH_AUTH_TOKEN" ]]; then
    token="$GH_AUTH_TOKEN"
  elif [[ -n "$GH_AUTH_TOKEN_FILE" ]]; then
    [[ -f "$GH_AUTH_TOKEN_FILE" ]] || sc_die "GitHub token file not found: $GH_AUTH_TOKEN_FILE"
    token="$(head -n 1 "$GH_AUTH_TOKEN_FILE" | tr -d '\r')"
  fi

  printf '%s' "$token"
}

prompt_for_gh_auth_token() {
  local token=""

  if ((SC_ASSUME_YES)); then
    sc_die "gh authentication requires a token in non-interactive mode. Use --github-token, --github-token-file, GH_TOKEN, or GITHUB_TOKEN."
  fi

  read -r -s -p "Enter GitHub token for $GITHUB_HOST: " token
  echo
  [[ -n "$token" ]] || sc_die "GitHub token cannot be empty."
  printf '%s' "$token"
}

phase_preflight() {
  local phase="$1"
  case "$phase" in
    precheck) sc_require_commands apt-get getent || return 1 ;;
    system_packages) sc_require_commands apt-get || return 1 ;;
    github_cli) sc_require_commands apt-get || return 1 ;;
    clone_repos) sc_require_commands git || return 1 ;;
    node_tooling) sc_require_commands git curl || return 1 ;;
    docker_tooling) sc_require_commands systemctl || return 1 ;;
    python_tooling) sc_require_commands git pipx || return 1 ;;
    git_identity) sc_require_commands git || return 1 ;;
    repo_dependencies) sc_require_commands git || return 1 ;;
    bootstrap_main) sc_require_commands git || return 1 ;;
    verify) sc_require_commands git python3 || return 1 ;;
  esac
}

phase_precheck() {
  sc_assert_ubuntu

  if ((EUID != 0)) && ! command -v sudo >/dev/null 2>&1; then
    sc_die "sudo is required when not running as root"
  fi

  [[ -n "$TARGET_USER" ]] || sc_die "--username resolved to empty value"
  [[ "$TARGET_USER" != "root" ]] || sc_die "--username must be non-root"
  [[ -n "$GIT_NAME" ]] || sc_die "--git-name cannot be empty"
  [[ -n "$GIT_EMAIL" ]] || sc_die "--git-email cannot be empty"
  [[ "$PYTHON_VERSION_PREFIX" =~ ^[0-9]+\.[0-9]+$ ]] || sc_die "--python-version-prefix must be in X.Y format"
  [[ "$GO_MIN_TOOLCHAIN" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || sc_die "--go-min-toolchain must be X.Y or X.Y.Z format"
  [[ "$CLICKHOUSE_APT_CHANNEL" == "stable" || "$CLICKHOUSE_APT_CHANNEL" == "lts" ]] || sc_die "--clickhouse-apt-channel must be stable or lts"
  [[ -n "$GITHUB_HOST" ]] || sc_die "--github-host cannot be empty"

  if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
    sc_die "User '$TARGET_USER' does not exist"
  fi

  if [[ -n "$GH_AUTH_TOKEN_FILE" && ! -f "$GH_AUTH_TOKEN_FILE" ]]; then
    sc_die "GitHub token file not found: $GH_AUTH_TOKEN_FILE"
  fi

  resolve_target_home

  if ((WORKSPACE_DIR_SET == 0)); then
    WORKSPACE_DIR="$TARGET_HOME/${LANGFUSE_WORKSPACE_SUBDIR:-langfuse}"
  fi

  if [[ "$WORKSPACE_DIR" == "~"* ]]; then
    WORKSPACE_DIR="${WORKSPACE_DIR/#\~/$TARGET_HOME}"
  fi

  sc_info "Configuration summary:"
  sc_info "  mode=$SC_MODE"
  sc_info "  target_user=$TARGET_USER"
  sc_info "  workspace_dir=$WORKSPACE_DIR"
  sc_info "  node_version=$NODE_VERSION"
  sc_info "  pnpm_version=$PNPM_VERSION"
  sc_info "  python_prefix=$PYTHON_VERSION_PREFIX"
  sc_info "  migrate_tags=$MIGRATE_BUILD_TAGS"
  sc_info "  go_min_toolchain=$GO_MIN_TOOLCHAIN"
  sc_info "  clickhouse_apt_channel=$CLICKHOUSE_APT_CHANNEL"
  sc_info "  github_host=$GITHUB_HOST"
  sc_info "  run_main_dx=$RUN_MAIN_DX"
  sc_info "  log_file=$SC_LOG_FILE"
  sc_info "  state_dir=$SC_STATE_DIR"

  sc_confirm_or_exit "Proceed with Langfuse environment setup"
}

phase_system_packages() {
  apt_update
  apt_install \
    git curl ca-certificates gnupg apt-transport-https lsb-release software-properties-common \
    build-essential pkg-config make unzip zip jq pipx golang-go \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev llvm \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

  if ! apt_install clickhouse-client; then
    sc_warn "Could not install clickhouse-client from default apt sources. Trying official ClickHouse repository."

    local clickhouse_key_url clickhouse_keyring clickhouse_repo_file arch repo_line tmp_key tmp_repo
    clickhouse_key_url="https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key"
    clickhouse_keyring="/usr/share/keyrings/clickhouse-keyring.gpg"
    clickhouse_repo_file="/etc/apt/sources.list.d/clickhouse.list"
    arch="$(dpkg --print-architecture)"
    repo_line="deb [signed-by=${clickhouse_keyring} arch=${arch}] https://packages.clickhouse.com/deb ${CLICKHOUSE_APT_CHANNEL} main"

    tmp_key="$(mktemp)"
    tmp_repo="$(mktemp)"
    sc_register_tmp_path "$tmp_key"
    sc_register_tmp_path "$tmp_repo"

    sc_run_sudo install -d -m 0755 /usr/share/keyrings
    sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_sudo curl -fsSL "$clickhouse_key_url" -o "$tmp_key"
    sc_run_sudo gpg --dearmor --yes -o "$clickhouse_keyring" "$tmp_key"

    printf '%s\n' "$repo_line" > "$tmp_repo"
    sc_run_sudo install -m 644 "$tmp_repo" "$clickhouse_repo_file"

    apt_update
    apt_install clickhouse-client || sc_die "Could not install clickhouse-client from official ClickHouse repository."
  fi

  if ! command -v clickhouse >/dev/null 2>&1; then
    local clickhouse_client_bin
    clickhouse_client_bin="$(command -v clickhouse-client || true)"
    if [[ -n "$clickhouse_client_bin" ]]; then
      sc_run_sudo install -d -m 755 /usr/local/bin
      sc_run_sudo ln -sfn "$clickhouse_client_bin" /usr/local/bin/clickhouse
      sc_info "Created clickhouse shim at /usr/local/bin/clickhouse -> $clickhouse_client_bin"
    fi
  fi

  local normalized_migrate_tags
  normalized_migrate_tags=",${MIGRATE_BUILD_TAGS// /,},"
  if [[ "$normalized_migrate_tags" == *",clickhouse,"* ]] && ! command -v clickhouse >/dev/null 2>&1; then
    sc_die "ClickHouse CLI is required for migrate tag 'clickhouse'. Install clickhouse client tools so 'clickhouse' is on PATH."
  fi

  local migrate_ref migrate_target q_migrate_target q_migrate_tags gotoolchain_value q_gotoolchain
  if [[ "$SC_MODE" == "latest" ]]; then
    migrate_ref="latest"
  else
    migrate_ref="$MIGRATE_VERSION"
  fi

  migrate_target="github.com/golang-migrate/migrate/v4/cmd/migrate@$migrate_ref"
  gotoolchain_value="go${GO_MIN_TOOLCHAIN}+auto"
  q_migrate_target="$(sc_quote "$migrate_target")"
  q_migrate_tags="$(sc_quote "$MIGRATE_BUILD_TAGS")"
  q_gotoolchain="$(sc_quote "$gotoolchain_value")"
  run_with_user_env "GOBIN=\"\$HOME/.local/bin\" GOTOOLCHAIN=$q_gotoolchain go install -tags $q_migrate_tags $q_migrate_target"
}

phase_github_cli() {
  apt_install gh

  if sc_run_as_user_cmd "$TARGET_USER" gh auth status --hostname "$GITHUB_HOST" >/dev/null 2>&1; then
    sc_info "gh already authenticated for $GITHUB_HOST"
    return
  fi

  if ((SC_DRY_RUN)); then
    sc_info "Dry-run: would authenticate gh for $TARGET_USER on $GITHUB_HOST"
    return
  fi

  local token=""
  token="$(load_gh_auth_token)"
  if [[ -z "$token" ]]; then
    token="$(prompt_for_gh_auth_token)"
  fi

  printf '%s\n' "$token" | sc_run_as_user_cmd "$TARGET_USER" gh auth login --hostname "$GITHUB_HOST" --git-protocol https --with-token
  token=""

  sc_run_as_user_cmd "$TARGET_USER" gh auth status --hostname "$GITHUB_HOST" >/dev/null 2>&1 || sc_die "gh authentication failed for host '$GITHUB_HOST'"
}

phase_clone_repos() {
  sc_run_as_user_cmd "$TARGET_USER" mkdir -p "$WORKSPACE_DIR"

  clone_or_update_repo "https://github.com/langfuse/langfuse.git" "$WORKSPACE_DIR/langfuse"
  clone_or_update_repo "https://github.com/langfuse/langfuse-python.git" "$WORKSPACE_DIR/langfuse-python"
  clone_or_update_repo "https://github.com/langfuse/langfuse-js.git" "$WORKSPACE_DIR/langfuse-js"
  clone_or_update_repo "https://github.com/langfuse/langfuse-docs.git" "$WORKSPACE_DIR/langfuse-docs"
}

phase_node_tooling() {
  sc_run_as_user "$TARGET_USER" "set -euo pipefail; export NVM_DIR=\"\$HOME/.nvm\"; if [[ ! -d \"\$NVM_DIR\" ]]; then git clone https://github.com/nvm-sh/nvm.git \"\$NVM_DIR\"; fi; cd \"\$NVM_DIR\"; git fetch --tags --quiet; git checkout v0.40.3"

  run_with_user_env "nvm install '$NODE_VERSION'; nvm alias default '$NODE_VERSION'; nvm use '$NODE_VERSION'; corepack enable; corepack prepare pnpm@'$PNPM_VERSION' --activate; node -v; pnpm -v"
}

phase_docker_tooling() {
  sc_run_sudo install -m 0755 -d /etc/apt/keyrings

  if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
    sc_retry "$SC_RETRY_ATTEMPTS" "$SC_RETRY_DELAY_SECONDS" sc_run_sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  fi
  sc_run_sudo chmod a+r /etc/apt/keyrings/docker.asc

  local codename arch repo_line tmp_file
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  arch="$(dpkg --print-architecture)"
  repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable"

  if ! sc_run_sudo grep -Fqx "$repo_line" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
    tmp_file="$(mktemp)"
    sc_register_tmp_path "$tmp_file"
    printf '%s\n' "$repo_line" > "$tmp_file"
    sc_run_sudo install -m 644 "$tmp_file" /etc/apt/sources.list.d/docker.list
  fi

  apt_update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sc_run_sudo systemctl enable --now docker
  sc_run_sudo usermod -aG docker "$TARGET_USER"
  sc_warn "User '$TARGET_USER' added to docker group. New login shell is required for group membership."
}

phase_python_tooling() {
  sc_run_as_user "$TARGET_USER" "set -euo pipefail; if [[ ! -d \"\$HOME/.pyenv\" ]]; then git clone https://github.com/pyenv/pyenv.git \"\$HOME/.pyenv\"; fi"

  if [[ "$SC_MODE" == "latest" ]]; then
    local prefix_regex
    prefix_regex="${PYTHON_VERSION_PREFIX//./\\.}"
    run_with_user_env "latest=\$(pyenv install --list | tr -d ' ' | grep -E '^${prefix_regex}\\.[0-9]+$' | tail -n1 || true); [[ -n \"\$latest\" ]] || latest='${PINNED_PYTHON_VERSION}'; pyenv install -s \"\$latest\"; pyenv global \"\$latest\"; pyenv rehash; python --version"
  else
    run_with_user_env "pyenv install -s '${PINNED_PYTHON_VERSION}'; pyenv global '${PINNED_PYTHON_VERSION}'; pyenv rehash; python --version"
  fi

  run_with_user_env "pipx ensurepath >/dev/null 2>&1 || true; if ! command -v poetry >/dev/null 2>&1; then pipx install poetry; fi; if [[ '$SC_MODE' == 'latest' ]]; then pipx upgrade poetry || true; fi; poetry --version"
}

phase_git_identity() {
  local include_file workspace_gitdir include_key tmp_include
  include_file="$TARGET_HOME/.gitconfig-hassiebbot"
  workspace_gitdir="${WORKSPACE_DIR%/}/"
  include_key="includeIf.gitdir:${workspace_gitdir}.path"
  tmp_include="$(mktemp)"
  sc_register_tmp_path "$tmp_include"

  {
    printf '%s\n' "[user]"
    printf '    name = %s\n' "$GIT_NAME"
    printf '    email = %s\n' "$GIT_EMAIL"
    printf '%s\n' "[github]"
    printf '    user = %s\n' "$GITHUB_USER"
  } > "$tmp_include"

  sc_run_sudo install -m 600 -o "$TARGET_USER" -g "$TARGET_USER" "$tmp_include" "$include_file"

  sc_run_as_user_cmd "$TARGET_USER" git config --global --unset-all "$include_key" || true
  sc_run_as_user_cmd "$TARGET_USER" git config --global "$include_key" "$include_file"

  sc_add_summary "Scoped Git identity configured via includeIf for $workspace_gitdir"
}

phase_repo_dependencies() {
  local main_repo py_repo js_repo docs_repo
  main_repo="$WORKSPACE_DIR/langfuse"
  py_repo="$WORKSPACE_DIR/langfuse-python"
  js_repo="$WORKSPACE_DIR/langfuse-js"
  docs_repo="$WORKSPACE_DIR/langfuse-docs"

  if [[ -f "$main_repo/.env.dev.example" && ! -f "$main_repo/.env" ]]; then
    sc_run_as_user_cmd "$TARGET_USER" cp "$main_repo/.env.dev.example" "$main_repo/.env"
  fi
  [[ -f "$main_repo/package.json" ]] && run_node_repo_cmd "$main_repo" "pnpm install --frozen-lockfile || pnpm install; pnpm run prepare"

  [[ -f "$js_repo/package.json" ]] && run_node_repo_cmd "$js_repo" "pnpm install --frozen-lockfile || pnpm install"

  if [[ -f "$docs_repo/.env.template" && ! -f "$docs_repo/.env" ]]; then
    sc_run_as_user_cmd "$TARGET_USER" cp "$docs_repo/.env.template" "$docs_repo/.env"
  fi
  [[ -f "$docs_repo/package.json" ]] && run_node_repo_cmd "$docs_repo" "pnpm install --frozen-lockfile || pnpm i"

  if [[ -f "$py_repo/.env.template" && ! -f "$py_repo/.env" ]]; then
    sc_run_as_user_cmd "$TARGET_USER" cp "$py_repo/.env.template" "$py_repo/.env"
  fi

  if [[ -f "$py_repo/pyproject.toml" ]]; then
    run_with_user_env "cd '$py_repo'; poetry self show plugins 2>/dev/null | grep -q 'poetry-dotenv-plugin' || poetry self add poetry-dotenv-plugin; pybin=\$(pyenv which python); poetry env use \"\$pybin\"; poetry install --all-extras; poetry run pre-commit install"
  fi
}

phase_bootstrap_main() {
  if ((RUN_MAIN_DX == 0)); then
    sc_info "Skipping main bootstrap (enable with --run-main-dx)"
    return
  fi

  local repo
  repo="$WORKSPACE_DIR/langfuse"
  [[ -f "$repo/package.json" ]] || sc_die "Cannot run dx: $repo/package.json not found"

  if ! run_node_repo_cmd "$repo" "printf 'Y\nY\n' | pnpm run dx"; then
    sc_warn "pnpm run dx failed on first attempt. Retrying once."
    run_node_repo_cmd "$repo" "printf 'Y\nY\n' | pnpm run dx"
  fi
}

phase_verify() {
  local repo main_repo py_repo js_repo docs_repo
  repo="$WORKSPACE_DIR"
  main_repo="$repo/langfuse"
  py_repo="$repo/langfuse-python"
  js_repo="$repo/langfuse-js"
  docs_repo="$repo/langfuse-docs"

  [[ -d "$main_repo/.git" ]] || sc_die "Missing repo: $main_repo"
  [[ -d "$py_repo/.git" ]] || sc_die "Missing repo: $py_repo"
  [[ -d "$js_repo/.git" ]] || sc_die "Missing repo: $js_repo"
  [[ -d "$docs_repo/.git" ]] || sc_die "Missing repo: $docs_repo"

  local node_v pnpm_v py_v poetry_v docker_v
  node_v="$(run_with_user_env "node -v")"
  pnpm_v="$(run_with_user_env "pnpm -v")"
  py_v="$(run_with_user_env "python -V")"
  poetry_v="$(run_with_user_env "poetry --version")"
  docker_v="$(sc_run_sudo docker compose version 2>/dev/null || true)"
  local gh_status="not-installed"

  if command -v gh >/dev/null 2>&1; then
    if sc_run_as_user_cmd "$TARGET_USER" gh auth status --hostname "$GITHUB_HOST" >/dev/null 2>&1; then
      gh_status="authenticated($GITHUB_HOST)"
    else
      gh_status="installed-not-authenticated($GITHUB_HOST)"
    fi
  fi

  sc_add_summary "Node: $node_v"
  sc_add_summary "Pnpm: $pnpm_v"
  sc_add_summary "Python: $py_v"
  sc_add_summary "Poetry: $poetry_v"
  sc_add_summary "GitHub CLI: $gh_status"
  if [[ -n "$docker_v" ]]; then
    sc_add_summary "Docker Compose: $docker_v"
  else
    sc_add_summary "Docker Compose: unavailable (check docker group/session)"
  fi
  sc_add_summary "Workspace ready at: $WORKSPACE_DIR"
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
      --mode)
        SC_MODE="${2:-}"
        shift 2
        ;;
      --frozen)
        SC_MODE="frozen"
        shift
        ;;
      --workspace-dir)
        WORKSPACE_DIR="${2:-}"
        WORKSPACE_DIR_SET=1
        shift 2
        ;;
      --username)
        TARGET_USER="${2:-}"
        shift 2
        ;;
      --python-version-prefix)
        PYTHON_VERSION_PREFIX="${2:-}"
        shift 2
        ;;
      --git-name)
        GIT_NAME="${2:-}"
        shift 2
        ;;
      --git-email)
        GIT_EMAIL="${2:-}"
        shift 2
        ;;
      --github-user)
        GITHUB_USER="${2:-}"
        shift 2
        ;;
      --github-host)
        GITHUB_HOST="${2:-}"
        shift 2
        ;;
      --github-token)
        GH_AUTH_TOKEN="${2:-}"
        shift 2
        ;;
      --github-token-file)
        GH_AUTH_TOKEN_FILE="${2:-}"
        shift 2
        ;;
      --run-main-dx)
        RUN_MAIN_DX=1
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
        sc_die "Phase '$phase' is present in both --only and --skip"
      fi
    done
  fi

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

  sc_info "Langfuse setup complete."
  sc_print_summary
  sc_warn "If docker commands fail, start a new login shell for group refresh."
}

main "$@"
